# Rake tasks for LDN (Land Degradation Neutrality) data preparation.
#
# Imports pre-dissolved geometry GPKGs (pa_ecoregion.gpkg, pa_ecoregion_country.gpkg)
# and key CSVs into the ldn_dissolved_geometries table with four dimensions:
# ecoregion, country, biome, and realm.
#
# Usage (inside Docker):
#   docker compose -f docker-compose.dev.yml exec backend \
#     rake ldn:import_geometries
#
# Or with a custom data directory:
#   LDN_DATA_DIR=/data/ldn rake ldn:import_geometries

LDN_DEFAULT_DATA_DIR = File.expand_path("../../db/data/ldn/../../../", __dir__)

namespace :ldn do
  desc "Import pre-dissolved geometries into ldn_dissolved_geometries (run once before seeding)"
  task import_geometries: :environment do
    data_dir = ENV.fetch("LDN_DATA_DIR", LDN_DEFAULT_DATA_DIR)
    conn = ActiveRecord::Base.connection

    eco_gpkg = File.join(data_dir, "pa_ecoregion.gpkg")
    country_eco_gpkg = File.join(data_dir, "pa_ecoregion_country.gpkg")
    eco_key_csv = File.join(data_dir, "pa_ecoregion_key.csv")
    country_key_csv = File.join(data_dir, "pa_ecoregion_country_key.csv")

    abort "ERROR: pa_ecoregion.gpkg not found in #{data_dir}" unless File.exist?(eco_gpkg)
    abort "ERROR: pa_ecoregion_country.gpkg not found in #{data_dir}" unless File.exist?(country_eco_gpkg)
    abort "ERROR: pa_ecoregion_key.csv not found in #{data_dir}" unless File.exist?(eco_key_csv)
    abort "ERROR: pa_ecoregion_country_key.csv not found in #{data_dir}" unless File.exist?(country_key_csv)

    dbcfg = ActiveRecord::Base.connection_db_config.configuration_hash
    pg_host = dbcfg[:host] || "localhost"
    pg_port = dbcfg[:port] || 5432
    pg_db = dbcfg[:database]
    pg_user = dbcfg[:username]
    pg_pass = dbcfg[:password]
    env = {"PGPASSWORD" => pg_pass.to_s}
    pg_dsn = "PG:host=#{pg_host} port=#{pg_port} dbname=#{pg_db} user=#{pg_user}"

    # ── Import pa_ecoregion.gpkg ──
    puts "Importing pa_ecoregion.gpkg via ogr2ogr..."
    cmd = [
      "ogr2ogr", "-f", "PostgreSQL", pg_dsn,
      eco_gpkg,
      "-nln", "_pa_ecoregion_raw", "-overwrite",
      "-lco", "GEOMETRY_NAME=geom",
      "-lco", "FID=ogc_fid",
      "-lco", "SPATIAL_INDEX=NONE",
      "-nlt", "PROMOTE_TO_MULTI",
      "-gt", "1000",
      "--config", "PG_USE_COPY", "YES",
      "-progress"
    ]
    raise "ogr2ogr failed for pa_ecoregion.gpkg" unless system(env, *cmd)

    # ── Import pa_ecoregion_country.gpkg ──
    puts "Importing pa_ecoregion_country.gpkg via ogr2ogr..."
    cmd = [
      "ogr2ogr", "-f", "PostgreSQL", pg_dsn,
      country_eco_gpkg,
      "-nln", "_pa_ecoregion_country_raw", "-overwrite",
      "-lco", "GEOMETRY_NAME=geom",
      "-lco", "FID=ogc_fid",
      "-lco", "SPATIAL_INDEX=NONE",
      "-nlt", "PROMOTE_TO_MULTI",
      "-gt", "1000",
      "--config", "PG_USE_COPY", "YES",
      "-progress"
    ]
    raise "ogr2ogr failed for pa_ecoregion_country.gpkg" unless system(env, *cmd)

    # ── Import key CSVs ──
    # Sanitize key CSVs: strip ".0" float suffixes from integer columns
    # (pandas may write int columns as floats when NaN is present)
    [eco_key_csv, country_key_csv].each do |csv_path|
      system("sed", "-i", 's/\\.0,/,/g; s/\\.0$//', csv_path.to_s)
    end

    puts "Importing key CSVs..."
    conn.execute("DROP TABLE IF EXISTS _eco_key")
    conn.execute(<<~SQL)
      CREATE TABLE _eco_key (
        unit_id  int,
        is_pa    int,
        eco_id   int,
        eco_name text,
        biome_num int,
        biome_name text,
        realm    text
      )
    SQL
    copy_csv(conn, "_eco_key", eco_key_csv)
    puts "  _eco_key: #{conn.select_value("SELECT count(*) FROM _eco_key")} rows"

    conn.execute("DROP TABLE IF EXISTS _eco_country_key")
    conn.execute(<<~SQL)
      CREATE TABLE _eco_country_key (
        unit_id      int,
        is_pa        int,
        eco_id       int,
        eco_name     text,
        biome_num    int,
        biome_name   text,
        realm        text,
        country_id   int,
        country_code text,
        country_name text
      )
    SQL
    copy_csv(conn, "_eco_country_key", country_key_csv)
    puts "  _eco_country_key: #{conn.select_value("SELECT count(*) FROM _eco_country_key")} rows"

    # ── Create/truncate target table ──
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

    total = 0

    # ── Dimension: ecoregion ──
    # One row per eco_id from pa_ecoregion, joined with key for names
    puts "Building ecoregion dimension..."
    conn.execute(<<~SQL)
      INSERT INTO ldn_dissolved_geometries (dimension, unit_id, properties, geom)
      SELECT
        'ecoregion',
        k.eco_id::text,
        jsonb_build_object(
          'ecoregion', k.eco_name,
          'biome', k.biome_name,
          'realm', k.realm
        ),
        ST_Multi(ST_Union(g.geom))
      FROM _pa_ecoregion_raw g
      JOIN _eco_key k ON g.unit_id = k.unit_id
      WHERE k.is_pa = 0
      GROUP BY k.eco_id, k.eco_name, k.biome_name, k.realm
    SQL
    count = conn.select_value("SELECT count(*) FROM ldn_dissolved_geometries WHERE dimension = 'ecoregion'")
    puts "  #{count} ecoregion geometries"
    total += count.to_i

    # ── Dimension: country ──
    # One row per country_id from pa_ecoregion_country, union of all ecoregion parts
    puts "Building country dimension..."
    conn.execute(<<~SQL)
      INSERT INTO ldn_dissolved_geometries (dimension, unit_id, properties, geom)
      SELECT
        'country',
        k.country_id::text,
        jsonb_build_object(
          'country', k.country_name,
          'country_code', k.country_code
        ),
        ST_Multi(ST_Union(g.geom))
      FROM _pa_ecoregion_country_raw g
      JOIN _eco_country_key k ON g.unit_id = k.unit_id
      WHERE k.is_pa = 0
      GROUP BY k.country_id, k.country_name, k.country_code
    SQL
    count = conn.select_value("SELECT count(*) FROM ldn_dissolved_geometries WHERE dimension = 'country'")
    puts "  #{count} country geometries"
    total += count.to_i

    # ── Dimension: biome ──
    # One row per biome_name from pa_ecoregion, union of all ecoregions sharing a biome
    puts "Building biome dimension..."
    conn.execute(<<~SQL)
      INSERT INTO ldn_dissolved_geometries (dimension, unit_id, properties, geom)
      SELECT
        'biome',
        k.biome_name,
        jsonb_build_object(
          'biome', k.biome_name,
          'realm', MODE() WITHIN GROUP (ORDER BY k.realm)
        ),
        ST_Multi(ST_Union(g.geom))
      FROM _pa_ecoregion_raw g
      JOIN _eco_key k ON g.unit_id = k.unit_id
      WHERE k.is_pa = 0 AND k.biome_name IS NOT NULL
      GROUP BY k.biome_name
    SQL
    count = conn.select_value("SELECT count(*) FROM ldn_dissolved_geometries WHERE dimension = 'biome'")
    puts "  #{count} biome geometries"
    total += count.to_i

    # ── Dimension: realm ──
    # One row per realm from pa_ecoregion, union of all ecoregions sharing a realm
    puts "Building realm dimension..."
    conn.execute(<<~SQL)
      INSERT INTO ldn_dissolved_geometries (dimension, unit_id, properties, geom)
      SELECT
        'realm',
        k.realm,
        jsonb_build_object('realm', k.realm),
        ST_Multi(ST_Union(g.geom))
      FROM _pa_ecoregion_raw g
      JOIN _eco_key k ON g.unit_id = k.unit_id
      WHERE k.is_pa = 0 AND k.realm IS NOT NULL
      GROUP BY k.realm
    SQL
    count = conn.select_value("SELECT count(*) FROM ldn_dissolved_geometries WHERE dimension = 'realm'")
    puts "  #{count} realm geometries"
    total += count.to_i

    # ── Index for fast lookups during seed ──
    conn.execute(<<~SQL)
      CREATE INDEX IF NOT EXISTS idx_ldn_dissolved_dim
        ON ldn_dissolved_geometries (dimension);
    SQL

    # ── Cleanup temp tables ──
    %w[_pa_ecoregion_raw _pa_ecoregion_country_raw _eco_key _eco_country_key].each do |t|
      conn.execute("DROP TABLE IF EXISTS #{t}")
    end

    puts "Done — #{total} dissolved geometries in ldn_dissolved_geometries."
  end

  desc "Show status of pre-dissolved geometries"
  task geometry_status: :environment do
    conn = ActiveRecord::Base.connection
    exists = conn.select_value(
      "SELECT to_regclass('public.ldn_dissolved_geometries') IS NOT NULL"
    )
    unless exists
      puts "Table ldn_dissolved_geometries does not exist. Run `rake ldn:import_geometries` first."
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

  def copy_csv(conn, table_name, csv_path)
    raw = conn.raw_connection
    raw.copy_data("COPY #{table_name} FROM STDIN CSV HEADER") do
      File.open(csv_path, "r") { |f| f.each_line { |l| raw.put_copy_data(l) } }
    end
  end
end
