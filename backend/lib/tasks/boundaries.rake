DATA_DIR = "/data/geoboundaries"

GPKG_FILES = {
  0 => File.join(DATA_DIR, "geoBoundariesCGAZ_ADM0.gpkg"),
  1 => File.join(DATA_DIR, "geoBoundariesCGAZ_ADM1.gpkg"),
  2 => File.join(DATA_DIR, "geoBoundariesCGAZ_ADM2.gpkg")
}.freeze

namespace :boundaries do
  desc "Import geoBoundaries CGAZ data into admin_boundaries table. " \
       "Mount .gpkg files to #{DATA_DIR} first. Set FORCE=1 to skip confirmation prompt. " \
       "Usage: docker compose run --rm -v /path/to/files:#{DATA_DIR}:ro backend rake boundaries:import"
  task import: :environment do
    # Pre-flight: files present?
    missing = GPKG_FILES.select { |_, path| !File.exist?(path) }
    if missing.any?
      puts "ERROR: Missing GeoPackage files in #{DATA_DIR}:"
      missing.each { |level, path| puts "  ADM#{level}: #{path}" }
      puts ""
      puts "Mount the data volume first. Example:"
      puts "  docker compose run --rm -v /path/to/gpkg/files:#{DATA_DIR}:ro backend rake boundaries:import"
      abort
    end

    # Pre-flight: tools available?
    abort "ERROR: ogr2ogr not found. GDAL must be installed (gdal-bin)." unless system("which ogr2ogr > /dev/null 2>&1")
    abort "ERROR: psql not found. PostgreSQL client must be installed." unless system("which psql > /dev/null 2>&1")

    # Build PG connection string for ogr2ogr
    pg_conn = if ENV["DATABASE_URL"].present?
      # ogr2ogr requires postgresql:// scheme, not postgis://
      ENV["DATABASE_URL"].sub(/\Apostgis:/, "postgresql:")
    else
      cfg = ActiveRecord::Base.connection_db_config.configuration_hash
      host = cfg[:host] || "localhost"
      port = cfg[:port] || 5432
      user = cfg[:username] || "postgres"
      pass = cfg[:password] || ""
      name = cfg[:database]
      "postgresql://#{user}:#{pass}@#{host}:#{port}/#{name}"
    end

    # Confirm before overwriting existing data
    current_count = AdminBoundary.count
    if current_count > 0
      puts "admin_boundaries table already has #{current_count} rows."
      if ENV["FORCE"] == "1"
        puts "FORCE=1 set — proceeding with truncate and re-import."
      else
        print "Truncate and re-import? [y/N] "
        unless $stdin.gets&.strip&.downcase == "y"
          puts "Aborted."
          next
        end
      end
    end

    puts "=== geoBoundaries → admin_boundaries import ==="
    puts "Data directory: #{DATA_DIR}"
    puts ""

    puts "Truncating admin_boundaries..."
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE admin_boundaries RESTART IDENTITY")

    GPKG_FILES.each do |level, gpkg_path|
      puts ""
      puts "Importing ADM#{level} from #{File.basename(gpkg_path)}..."

      layer_name = `ogrinfo -q "#{gpkg_path}" 2>/dev/null`.lines.first&.strip
        &.sub(/^\d+:\s*/, "")&.sub(/\s*\(.*/, "")
      abort "ERROR: Could not determine layer name in #{gpkg_path}" if layer_name.blank?

      temp_table = "temp_adm#{level}_import"

      success = system(
        "ogr2ogr", "-f", "PostgreSQL", "PG:#{pg_conn}", gpkg_path, layer_name,
        "-nln", temp_table, "-overwrite",
        "-lco", "GEOMETRY_NAME=geom", "-lco", "FID=ogc_fid",
        "-lco", "SPATIAL_INDEX=NONE",
        "-t_srs", "EPSG:4326", "-nlt", "PROMOTE_TO_MULTI",
        "-gt", "1000",
        "--config", "PG_USE_COPY", "YES", "-progress"
      )
      abort "ERROR: ogr2ogr failed for ADM#{level}" unless success

      conn = ActiveRecord::Base.connection

      insert_sql = case level
      when 0
        <<~SQL
          INSERT INTO admin_boundaries (name, iso_code, admin_level, parent_iso_code, geom, created_at, updated_at)
          SELECT "shapename", "shapegroup", 0, NULL, geom, NOW(), NOW()
          FROM #{temp_table}
        SQL
      when 1
        <<~SQL
          INSERT INTO admin_boundaries (name, iso_code, admin_level, parent_iso_code, geom, created_at, updated_at)
          SELECT "shapename",
                 COALESCE("shapeid", "shapegroup" || '_' || "shapename"),
                 1, "shapegroup", geom, NOW(), NOW()
          FROM #{temp_table}
        SQL
      when 2
        <<~SQL
          INSERT INTO admin_boundaries (name, iso_code, admin_level, parent_iso_code, geom, created_at, updated_at)
          SELECT COALESCE("shapename", "shapeid", 'Unknown'),
                 COALESCE("shapeid", "shapegroup" || '_' || COALESCE("shapename", 'unknown')),
                 2, "shapegroup", geom, NOW(), NOW()
          FROM #{temp_table}
        SQL
      end

      # Insert in batches to avoid PostgreSQL OOM on large geometry datasets
      total_in_temp = conn.select_value("SELECT count(*) FROM #{temp_table}").to_i
      batch_size = 2000

      if total_in_temp > batch_size
        puts "    Inserting #{total_in_temp} rows in batches of #{batch_size}..."
        inserted = 0
        while inserted < total_in_temp
          batch_sql = insert_sql.chomp + " ORDER BY ogc_fid LIMIT #{batch_size} OFFSET #{inserted}"
          begin
            conn.execute(batch_sql)
          rescue ActiveRecord::ConnectionFailed, PG::ConnectionBad
            puts "    Connection lost after #{inserted} rows, reconnecting..."
            ActiveRecord::Base.connection.reconnect!
            conn = ActiveRecord::Base.connection
            retry
          end
          inserted += batch_size
          puts "    #{[inserted, total_in_temp].min}/#{total_in_temp} rows inserted"
        end
      else
        conn.execute(insert_sql)
      end

      conn.execute("DROP TABLE IF EXISTS #{temp_table}")

      puts "  ADM#{level}: #{AdminBoundary.where(admin_level: level).count} boundaries imported"
    end

    puts ""
    puts "Cleaning geometries (ST_MakeValid + clip to Web Mercator extent)..."
    # Process one row at a time — ST_MakeValid + ST_Intersection on complex
    # multipolygons (especially country-level) is very memory-intensive and
    # can cause PostgreSQL to OOM even on small batches.
    [0, 1, 2].each do |level|
      clean_conn = ActiveRecord::Base.connection
      dirty_ids = clean_conn.select_values(<<~SQL)
        SELECT id FROM admin_boundaries
        WHERE admin_level = #{level}
          AND (NOT ST_IsValid(geom)
               OR NOT ST_CoveredBy(geom, ST_MakeEnvelope(-180, -85.051129, 180, 85.051129, 4326)))
        ORDER BY id
      SQL
      puts "  ADM#{level}: #{dirty_ids.size} geometries to clean..."

      dirty_ids.each_with_index do |row_id, idx|
        retries = 0
        begin
          clean_conn.execute(<<~SQL)
            UPDATE admin_boundaries
            SET geom = ST_Multi(ST_CollectionExtract(
              ST_Intersection(
                ST_MakeValid(geom),
                ST_MakeEnvelope(-180, -85.051129, 180, 85.051129, 4326)
              ),
              3
            ))
            WHERE id = #{row_id.to_i}
          SQL
        rescue ActiveRecord::ConnectionFailed, PG::ConnectionBad => e
          retries += 1
          if retries <= 3
            puts "    Row #{row_id}: connection lost (attempt #{retries}/3), reconnecting..."
            sleep(retries * 2)
            ActiveRecord::Base.connection.reconnect!
            clean_conn = ActiveRecord::Base.connection
            retry
          else
            puts "    Row #{row_id}: failed after #{retries} attempts: #{e.message}"
            raise
          end
        end
        puts "    #{idx + 1}/#{dirty_ids.size} cleaned" if ((idx + 1) % 50).zero? || idx + 1 == dirty_ids.size
      end
      puts "  ADM#{level}: done."
    end

    puts ""
    puts "=== Import complete ==="
    puts "  ADM0 (countries):        #{AdminBoundary.countries.count}"
    puts "  ADM1 (provinces/states): #{AdminBoundary.provinces.count}"
    puts "  ADM2 (districts):        #{AdminBoundary.districts.count}"
    puts "  Total:                   #{AdminBoundary.count}"
    puts ""
    puts "Next steps:"
    puts "  1. Restart Martin:  docker service update --force <martin-service>"
    puts "  2. Invalidate CDN:  scripts/invalidate-martin-cache.sh --staging  (or --production)"
  end

  desc "Show current admin_boundaries statistics"
  task status: :environment do
    unless AdminBoundary.table_exists?
      puts "admin_boundaries table does not exist. Run 'rails db:migrate' first."
      next
    end

    total = AdminBoundary.count
    if total == 0
      puts "admin_boundaries table is EMPTY."
      puts "Run 'rake boundaries:import' with the data volume mounted to load data."
    else
      puts "admin_boundaries:"
      puts "  ADM0 (countries):        #{AdminBoundary.countries.count}"
      puts "  ADM1 (provinces/states): #{AdminBoundary.provinces.count}"
      puts "  ADM2 (districts):        #{AdminBoundary.districts.count}"
      puts "  Total:                   #{total}"
    end
  end

  desc "Clear all admin_boundaries data"
  task clear: :environment do
    count = AdminBoundary.count
    if count == 0
      puts "admin_boundaries table is already empty."
      next
    end

    print "Delete #{count} boundary records? [y/N] "
    if $stdin.gets&.strip&.downcase == "y"
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE admin_boundaries RESTART IDENTITY")
      puts "Cleared."
    else
      puts "Aborted."
    end
  end
end
