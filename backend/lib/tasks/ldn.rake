# Rake tasks for LDN (Land Degradation Neutrality) data preparation.
#
# Builds the ldn_dissolved_geometries table from raw geometry tables
# (_pa_ecoregion_raw, _pa_ecoregion_country_raw) imported by host-side
# ogr2ogr in setup_ldn_data.sh, joined with key CSVs for metadata.
#
# Stores ecoregion-level and country-ecoregion-level polygons with
# rich properties (biome, realm, country, etc.). Higher-level views
# (biome, realm, country) are created at seed time by projecting the
# unit_id from properties — no ST_Union aggregation needed.
#
# Usage:
#   # 1. Import GPKGs on the host (setup_ldn_data.sh handles this)
#   # 2. Then build dimensions inside the container:
#   rake ldn:build_dimensions
#
# Or with a custom data directory:
#   LDN_DATA_DIR=/data/ldn rake ldn:build_dimensions

LDN_DEFAULT_DATA_DIR = File.expand_path("../../db/data/ldn/../../../", __dir__)

namespace :ldn do
  desc "Build geometry table from raw GPKGs already imported via ogr2ogr (host-side)"
  task build_dimensions: :environment do
    data_dir = ENV.fetch("LDN_DATA_DIR", LDN_DEFAULT_DATA_DIR)
    conn = ActiveRecord::Base.connection

    eco_key_csv = File.join(data_dir, "pa_ecoregion_key.csv")
    country_key_csv = File.join(data_dir, "pa_ecoregion_country_key.csv")

    abort "ERROR: pa_ecoregion_key.csv not found in #{data_dir}" unless File.exist?(eco_key_csv)
    abort "ERROR: pa_ecoregion_country_key.csv not found in #{data_dir}" unless File.exist?(country_key_csv)

    # Verify raw tables exist (imported by host-side ogr2ogr)
    %w[_pa_ecoregion_raw _pa_ecoregion_country_raw].each do |t|
      count = conn.select_value("SELECT count(*) FROM #{t}")
      puts "  #{t}: #{count} rows"
    rescue => e
      abort "ERROR: Table #{t} not found — run ogr2ogr import first. (#{e.message})"
    end

    # ── Import key CSVs ──
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

    # ── Ecoregion polygons ──
    # One row per ecoregion (eco_id) with biome/realm in properties.
    # The seed copies these into scope_dataset_geometries with unit_id
    # projected from properties for biome/realm/ecoregion views.
    puts "Loading ecoregion geometries..."
    conn.execute(<<~SQL)
      INSERT INTO ldn_dissolved_geometries (dimension, unit_id, properties, geom)
      SELECT
        'ecoregion',
        k.eco_id::text,
        jsonb_build_object(
          'eco_id', k.eco_id,
          'ecoregion', k.eco_name,
          'biome', k.biome_name,
          'realm', k.realm
        ),
        g.geom
      FROM _pa_ecoregion_raw g
      JOIN _eco_key k ON g.unit_id = k.unit_id
      WHERE k.is_pa = 0
    SQL
    count = conn.select_value("SELECT count(*) FROM ldn_dissolved_geometries WHERE dimension = 'ecoregion'")
    puts "  #{count} ecoregion geometries"
    total += count.to_i

    # ── Country-ecoregion polygons ──
    # One row per (country × ecoregion) with country info in properties.
    # Used for country-level views — seed projects unit_id from
    # properties->>'country_id' so all polygons in a country highlight together.
    puts "Loading country-ecoregion geometries..."
    conn.execute(<<~SQL)
      INSERT INTO ldn_dissolved_geometries (dimension, unit_id, properties, geom)
      SELECT
        'country_ecoregion',
        k.country_id::text || ':' || k.eco_id::text,
        jsonb_build_object(
          'country_id', k.country_id,
          'country_code', k.country_code,
          'country', k.country_name,
          'eco_id', k.eco_id,
          'ecoregion', k.eco_name,
          'biome', k.biome_name,
          'realm', k.realm
        ),
        g.geom
      FROM _pa_ecoregion_country_raw g
      JOIN _eco_country_key k ON g.unit_id = k.unit_id
      WHERE k.is_pa = 0
    SQL
    count = conn.select_value("SELECT count(*) FROM ldn_dissolved_geometries WHERE dimension = 'country_ecoregion'")
    puts "  #{count} country-ecoregion geometries"
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

    puts "Done — #{total} geometries in ldn_dissolved_geometries."
  end

  desc "Show status of pre-dissolved geometries"
  task geometry_status: :environment do
    conn = ActiveRecord::Base.connection
    exists = conn.select_value(
      "SELECT to_regclass('public.ldn_dissolved_geometries') IS NOT NULL"
    )
    unless exists
      puts "Table ldn_dissolved_geometries does not exist. Run `rake ldn:build_dimensions` first."
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
