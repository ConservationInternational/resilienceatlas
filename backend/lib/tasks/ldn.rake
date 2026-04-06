# Rake tasks for LDN (Land Degradation Neutrality) data preparation.
#
# The geometries in every variant GPKG (JRC, Trends.Earth, FAO-WOCAT) are
# identical — only the statistical attributes differ.  This task dissolves
# the geometries ONCE from any single GPKG and stores the results in a
# persistent table that the seed script copies from.
#
# Usage (inside Docker):
#   docker compose -f docker-compose.dev.yml exec backend \
#     rake ldn:dissolve_geometries
#
# Or with a custom data directory:
#   LDN_DATA_DIR=/data/ldn rake ldn:dissolve_geometries

LDN_DEFAULT_DATA_DIR = File.expand_path("../../db/data/ldn/../../../", __dir__)

DISSOLVE_DIMENSIONS = {
  "ecoregion" => {
    unit_id_expr: "eco_id::text",
    group_by_expr: "eco_id",
    properties_expr: "jsonb_build_object('ecoregion', MAX(ecoregion), 'biome', MAX(biome), 'realm', MAX(realm))",
    where_clause: "eco_id IS NOT NULL"
  },
  "country" => {
    unit_id_expr: "admin0_id::int::text",
    group_by_expr: "admin0_id::int",
    properties_expr: "jsonb_build_object('country', MAX(country))",
    where_clause: "admin0_id IS NOT NULL"
  },
  "biome" => {
    unit_id_expr: "biome",
    group_by_expr: "biome",
    properties_expr: "jsonb_build_object('biome', MAX(biome), 'realm', MODE() WITHIN GROUP (ORDER BY realm))",
    where_clause: "biome IS NOT NULL"
  }
}.freeze

namespace :ldn do
  desc "Dissolve geometries from one GPKG into ldn_dissolved_geometries (run once before seeding)"
  task dissolve_geometries: :environment do
    data_dir = ENV.fetch("LDN_DATA_DIR", LDN_DEFAULT_DATA_DIR)
    conn = ActiveRecord::Base.connection

    # Pick any one GPKG (geometries are identical across variants)
    gpkg_path = %w[JRC Trends.Earth FAO-WOCAT].lazy.map { |mode|
      File.join(data_dir, "TrendsEarth_LDN_2000-2023_#{mode}_country_ecoregion_land_types.gpkg")
    }.detect { |p| File.exist?(p) }

    abort "ERROR: No LDN GPKG found in #{data_dir}" unless gpkg_path
    puts "Using GPKG: #{gpkg_path}"

    # Import to _gpkg_raw via ogr2ogr
    import_gpkg_raw(conn, gpkg_path, data_dir)

    # Create/truncate the target table
    conn.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS ldn_dissolved_geometries (
        id          serial PRIMARY KEY,
        dimension   text NOT NULL,
        unit_id     text NOT NULL,
        properties  jsonb,
        geom        geometry(MultiPolygon, 4326)
      );
      TRUNCATE ldn_dissolved_geometries;
    SQL

    # Dissolve each dimension
    total = 0
    DISSOLVE_DIMENSIONS.each do |dimension, cfg|
      puts "Dissolving #{dimension}..."
      conn.execute(<<~SQL)
        INSERT INTO ldn_dissolved_geometries (dimension, unit_id, properties, geom)
        SELECT
          '#{dimension}',
          (#{cfg[:unit_id_expr]})::text,
          #{cfg[:properties_expr]},
          ST_Multi(ST_Union(geom))
        FROM _gpkg_raw
        WHERE #{cfg[:where_clause]}
        GROUP BY #{cfg[:group_by_expr]}
      SQL
      count = conn.select_value(
        "SELECT count(*) FROM ldn_dissolved_geometries WHERE dimension = '#{dimension}'"
      )
      puts "  #{count} geometries"
      total += count.to_i
    end

    # Index for fast lookups during seed
    conn.execute(<<~SQL)
      CREATE INDEX IF NOT EXISTS idx_ldn_dissolved_dim
        ON ldn_dissolved_geometries (dimension);
    SQL

    # Cleanup temp tables
    %w[_gpkg_raw _eco_lkp _adm0_lkp].each { |t| conn.execute("DROP TABLE IF EXISTS #{t}") }

    puts "Done — #{total} dissolved geometries in ldn_dissolved_geometries."
  end

  desc "Show status of pre-dissolved geometries"
  task dissolve_status: :environment do
    conn = ActiveRecord::Base.connection
    exists = conn.select_value(
      "SELECT to_regclass('public.ldn_dissolved_geometries') IS NOT NULL"
    )
    unless exists
      puts "Table ldn_dissolved_geometries does not exist. Run `rake ldn:dissolve_geometries` first."
      next
    end

    rows = conn.exec_query(
      "SELECT dimension, count(*) AS count FROM ldn_dissolved_geometries GROUP BY dimension ORDER BY dimension"
    )
    if rows.empty?
      puts "Table exists but is empty."
    else
      puts "ldn_dissolved_geometries:"
      rows.each { |r| puts "  #{r["dimension"]}: #{r["count"]} geometries" }
    end
  end

  # ── Shared helpers ──

  def import_gpkg_raw(conn, gpkg_path, data_dir)
    require "csv"
    dbcfg = ActiveRecord::Base.connection_db_config.configuration_hash
    pg_host = dbcfg[:host] || "localhost"
    pg_port = dbcfg[:port] || 5432
    pg_db = dbcfg[:database]
    pg_user = dbcfg[:username]
    pg_pass = dbcfg[:password]

    puts "Importing GPKG via ogr2ogr..."
    env = {"PGPASSWORD" => pg_pass.to_s}
    pg_dsn = "PG:host=#{pg_host} port=#{pg_port} dbname=#{pg_db} user=#{pg_user}"
    cmd = [
      "ogr2ogr", "-f", "PostgreSQL", pg_dsn,
      gpkg_path, "land_types",
      "-nln", "_gpkg_raw", "-overwrite",
      "-lco", "GEOMETRY_NAME=geom",
      "-lco", "FID=ogc_fid",
      "-nlt", "PROMOTE_TO_MULTI"
    ]
    raise "ogr2ogr failed for #{gpkg_path}" unless system(env, *cmd)

    puts "Enriching with area, realm, and country..."
    conn.execute(<<~SQL)
      ALTER TABLE _gpkg_raw
        ADD COLUMN IF NOT EXISTS area_km2 double precision,
        ADD COLUMN IF NOT EXISTS realm text,
        ADD COLUMN IF NOT EXISTS country text;
    SQL
    conn.execute("UPDATE _gpkg_raw SET area_km2 = ST_Area(geom::geography) / 1e6")

    eco_csv = ENV.fetch("LDN_ECOREGION_KEY") { File.join(data_dir, "ecoregion_key.csv") }
    if File.exist?(eco_csv)
      conn.execute("CREATE TEMP TABLE IF NOT EXISTS _eco_lkp (eco_id int, eco_name text, biome_num int, biome_name text, realm text)")
      conn.execute("TRUNCATE _eco_lkp")
      copy_csv(conn, "_eco_lkp", eco_csv)
      conn.execute("UPDATE _gpkg_raw r SET realm = e.realm FROM _eco_lkp e WHERE r.eco_id = e.eco_id")
      puts "  Realm lookup applied"
    end

    admin0_csv = ENV.fetch("LDN_ADMIN0_KEY") { File.join(data_dir, "admin0_key.csv") }
    if File.exist?(admin0_csv)
      conn.execute("CREATE TEMP TABLE IF NOT EXISTS _adm0_lkp (id int, shape_group text, shape_name text, shape_type text)")
      conn.execute("TRUNCATE _adm0_lkp")
      copy_csv(conn, "_adm0_lkp", admin0_csv)
      conn.execute("UPDATE _gpkg_raw r SET country = a.shape_name FROM _adm0_lkp a WHERE r.admin0_id::int = a.id")
      puts "  Country lookup applied"
    end
  end

  def copy_csv(conn, table_name, csv_path)
    raw = conn.raw_connection
    raw.copy_data("COPY #{table_name} FROM STDIN CSV HEADER") do
      File.open(csv_path, "r") { |f| f.each_line { |l| raw.put_copy_data(l) } }
    end
  end
end
