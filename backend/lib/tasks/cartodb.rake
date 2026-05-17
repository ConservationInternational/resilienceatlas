# Rake tasks for importing CartoDB data and updating formerly CartoDB layer rows.
#
# Workflow:
#   1. Run `export_vectors_bash.sh export` on the CartoDB server to upload .gpkg files to S3.
#   2. Run `export_tables_bash.sh export` for any non-spatial tables (optional).
#   3. Run `rake cartodb:import_tables` to download and load those files into PostgreSQL.
#      Vectors (.gpkg) are imported via ogr2ogr; non-spatial tables (.csv.gz) via COPY.
#   4. Run `rake cartodb:update_layer_references` to update the formerly CartoDB layer rows.
#   5. Manually review each layer in the admin UI: set a valid layer_provider and layer_config,
#      then re-publish.
#
# The vector export script produces GeoPackage files named {schema}_{table}.gpkg (e.g.
# public_yam_gh.gpkg) at a separate S3 prefix from the non-spatial CSV.GZ tables.
# Both local-directory (CSV only) and S3 sources are supported.

# ---------------------------------------------------------------------------
# Shared helpers (at file scope so all tasks can call them)
# ---------------------------------------------------------------------------

module CartodbRakeHelpers
  # Extract bare table names from FROM / JOIN clauses of a SQL string.
  # Handles schema-qualified names (schema.table) and SQL aliases.
  # Returns an array of lowercase table-name strings, deduplicated.
  def self.extract_table_names_from_sql(sql)
    return [] if sql.blank?

    sql
      .scan(/\b(?:FROM|JOIN)\s+(?:"?\w+"?\.)?"?(\w+)"?/i)
      .flatten
      .map(&:downcase)
      .reject { |t| %w[select where lateral values unnest generate_series].include?(t) }
      .uniq
  end

  # Parse { schema:, table: } from a {schema}_{table}.csv.gz filename.
  # Splits only on the FIRST underscore because CartoDB schema names are short
  # (e.g. "public") while table names may themselves contain underscores.
  def self.parse_export_filename(basename)
    name = basename.sub(/\.csv\.gz\z/, "")
    idx = name.index("_")
    return nil unless idx

    {schema: name[0...idx], table: name[(idx + 1)..]}
  end

  # Parse { schema:, table: } from a {schema}_{table}.gpkg filename.
  # Same convention as parse_export_filename but for GeoPackage vector exports.
  def self.parse_vector_filename(basename)
    name = basename.sub(/\.gpkg\z/, "")
    idx = name.index("_")
    return nil unless idx

    {schema: name[0...idx], table: name[(idx + 1)..]}
  end

  # Load the tables.csv manifest produced by the export script.
  # Returns: { "public_foo.csv.gz" => { schema: "public", table: "foo" }, ... }
  def self.load_manifest(path)
    require "csv"
    return {} unless File.exist?(path.to_s)

    CSV.foreach(path, headers: true).each_with_object({}) do |row, h|
      next if row["schema"].blank? || row["table"].blank?

      key = "#{row["schema"]}_#{row["table"]}.csv.gz"
      h[key] = {schema: row["schema"], table: row["table"]}
    end
  end

  # Sample up to +limit+ data rows from a gzipped CSV file and infer a
  # PostgreSQL column type for each column.  Falls back to TEXT for anything
  # that does not look like a plain integer, decimal, or boolean.
  def self.infer_column_types(gz_path, limit: 1_000)
    require "csv"
    require "zlib"

    col_samples = {}

    Zlib::GzipReader.open(gz_path) do |gz|
      csv = CSV.new(gz, headers: true)
      csv.each_with_index do |row, idx|
        break if idx >= limit

        row.each do |col, val|
          col_samples[col] ||= []
          col_samples[col] << val if val && !val.empty?
        end
      end
    end

    col_samples.transform_values do |vals|
      next "text" if vals.empty?

      if vals.all? { |v| v.match?(/\A-?\d+\z/) }
        "bigint"
      elsif vals.all? { |v| v.match?(/\A-?\d+\.?\d*(?:[eE][+-]?\d+)?\z/) }
        "double precision"
      elsif vals.all? { |v| v.match?(/\A(?:true|false|t|f|yes|no)\z/i) }
        "boolean"
      else
        "text"
      end
    end
  end

  # Strip CartoDB-internal columns (cartodb_id, the_geom_webmercator, the_geom)
  # from a SELECT list and fix up any resulting comma artifacts.
  CARTODB_INTERNAL_COLS = %w[cartodb_id the_geom_webmercator the_geom].freeze

  def self.strip_cartodb_columns(sql)
    return sql if sql.blank?

    cleaned = sql.dup
    CARTODB_INTERNAL_COLS.each do |col|
      # Remove:  alias.col,   col,   (trailing comma variants)
      cleaned.gsub!(/\b\w+\.#{col}\b[ \t]*,[ \t]*/i, "")
      cleaned.gsub!(/\b#{col}\b[ \t]*,[ \t]*/i, "")
      # Remove:  , alias.col   , col   (leading comma variants)
      cleaned.gsub!(/,[ \t]*\b\w+\.#{col}\b/i, "")
      cleaned.gsub!(/,[ \t]*\b#{col}\b/i, "")
      # Remove bare remnants (last column or only column)
      cleaned.gsub!(/\b\w+\.#{col}\b/i, "")
      cleaned.gsub!(/\b#{col}\b/i, "")
    end

    # Fix artefacts: "SELECT ," → "SELECT", ", FROM" → " FROM", double commas
    cleaned.gsub!(/\bSELECT\s*,/i, "SELECT")
    cleaned.gsub!(/,\s*\bFROM\b/i, " FROM")
    cleaned.gsub!(/[ \t]*,[ \t]*,[ \t]*/m, ", ")
    cleaned.strip
  end
end

# ---------------------------------------------------------------------------
# Rake namespace
# ---------------------------------------------------------------------------

namespace :cartodb do
  desc <<~DESC
    Import CartoDB spatial vectors (.gpkg) and non-spatial tables (.csv.gz) from S3 into PostgreSQL.

    Vectors are the primary data source: each {schema}_{table}.gpkg file on S3 is imported
    into the target schema via ogr2ogr.  Non-spatial tables (exported as {schema}_{table}.csv.gz)
    are imported using PostgreSQL COPY.  Only tables actually referenced by formerly CartoDB
    layers (layer_provider=NULL, published=false, query present) are imported.

    Required:
      CARTODB_S3_BUCKET=<bucket>        S3 bucket name

    Optional:
      CARTODB_VECTORS_S3_PREFIX=<p>     S3 prefix for .gpkg vector files
                                          (default: cartodb_exports/vectors/)
      CARTODB_TABLES_S3_PREFIX=<p>      S3 prefix for .csv.gz non-spatial files
                                          (default: cartodb_exports/non-spatial/)
      CARTODB_EXPORT_DIR=<path>         Local directory for .csv.gz files (non-spatial only,
                                          used when CARTODB_S3_BUCKET is not set)
      CARTODB_IMPORT_SCHEMA=<schema>    Target PostgreSQL schema (default: ra_vector)
      FORCE=1                           Overwrite existing tables without prompting

    Usage:
      rake cartodb:import_tables CARTODB_S3_BUCKET=my-bucket
      rake cartodb:import_tables CARTODB_S3_BUCKET=my-bucket \\
        CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \\
        CARTODB_TABLES_S3_PREFIX=cartodb-tables/
  DESC
  task import_tables: :environment do
    require "csv"
    require "zlib"
    require "tmpdir"

    s3_bucket = ENV.fetch("CARTODB_S3_BUCKET", "")
    vectors_prefix = ENV.fetch("CARTODB_VECTORS_S3_PREFIX", "cartodb_exports/vectors/")
    tables_prefix = ENV.fetch("CARTODB_TABLES_S3_PREFIX", "cartodb_exports/non-spatial/")
    export_dir = ENV.fetch("CARTODB_EXPORT_DIR", "")
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    force = ENV["FORCE"] == "1"
    use_s3 = s3_bucket.present?

    # ── Pre-flight checks ───────────────────────────────────────────────────

    if !use_s3 && !(export_dir.present? && Dir.exist?(export_dir))
      abort "ERROR: No export source found.\n" \
            "  Set CARTODB_S3_BUCKET=<bucket> or CARTODB_EXPORT_DIR=<path>.\n" \
            "  (CARTODB_EXPORT_DIR only covers non-spatial .csv.gz tables.)"
    end

    if use_s3 && !system("which aws > /dev/null 2>&1")
      abort "ERROR: aws CLI not found. Install awscli to download from S3."
    end

    unless system("which ogr2ogr > /dev/null 2>&1")
      abort "ERROR: ogr2ogr not found. Install gdal-bin to import .gpkg vector files."
    end

    ar_conn = ActiveRecord::Base.connection
    raw_conn = ar_conn.raw_connection  # PG::Connection – used for streaming COPY

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

    # ── 0. Collect referenced table names from flagged layers ────────────────

    flagged_layers = Layer
      .where(layer_provider: nil, published: false)
      .where.not(query: [nil, ""])

    if flagged_layers.empty?
      abort "ERROR: No formerly CartoDB layers found " \
            "(layer_provider=NULL, published=false, query present). Nothing to import."
    end

    referenced_table_names = flagged_layers
      .flat_map { |layer| CartodbRakeHelpers.extract_table_names_from_sql(layer.query) }
      .uniq
      .sort

    if referenced_table_names.empty?
      abort "ERROR: #{flagged_layers.count} flagged layer(s) found but no table names " \
            "could be parsed from their queries. Check the query column for those layers."
    end

    puts "Found #{flagged_layers.count} flagged layer(s) referencing " \
         "#{referenced_table_names.size} unique table name(s):"
    referenced_table_names.each { |t| puts "  - #{t}" }
    puts ""

    Dir.mktmpdir("cartodb_import") do |tmpdir|
      # ── 1. Discover available files ─────────────────────────────────────────

      # 1a. Vectors: .gpkg files from S3 vectors prefix
      gpkg_basenames = if use_s3
        puts "Listing s3://#{s3_bucket}/#{vectors_prefix} ..."
        list_output = `aws s3 ls "s3://#{s3_bucket}/#{vectors_prefix}" 2>&1`
        abort "ERROR: aws s3 ls failed for vectors prefix:\n#{list_output}" unless $?.success?
        files = list_output.scan(/(\S+\.gpkg)\s*$/).flatten
        puts "Found #{files.size} .gpkg file(s) at vectors prefix."
        files
      else
        []  # local vector import not supported; set CARTODB_S3_BUCKET
      end

      # 1b. Non-spatial tables: .csv.gz from S3 tables prefix or local directory
      gz_basenames = if use_s3
        puts "Listing s3://#{s3_bucket}/#{tables_prefix} ..."
        list_output = `aws s3 ls "s3://#{s3_bucket}/#{tables_prefix}" 2>&1`
        if $?.success?
          files = list_output.scan(/(\S+\.csv\.gz)\s*$/).flatten
          puts "Found #{files.size} .csv.gz file(s) at tables prefix."
          files
        else
          puts "NOTE: Tables prefix not accessible (#{tables_prefix}): #{list_output.strip}"
          puts "      Non-spatial table import will be skipped."
          []
        end
      elsif export_dir.present? && Dir.exist?(export_dir)
        files = Dir.glob(File.join(export_dir, "*.csv.gz")).map { |f| File.basename(f) }
        puts "Found #{files.size} .csv.gz file(s) in #{export_dir}."
        files
      else
        []
      end

      # ── 2. Build table → file mappings and report coverage ──────────────────

      gpkg_table_to_file = gpkg_basenames.each_with_object({}) do |basename, h|
        info = CartodbRakeHelpers.parse_vector_filename(basename)
        h[info[:table]] = basename if info
      end

      gz_table_to_file = gz_basenames.each_with_object({}) do |basename, h|
        info = CartodbRakeHelpers.parse_export_filename(basename)
        h[info[:table]] = basename if info
      end

      # Vectors take priority; non-spatial tables fill the remainder
      to_import_as_vector = referenced_table_names.select { |t| gpkg_table_to_file.key?(t) }
      to_import_as_table = (referenced_table_names - to_import_as_vector).select { |t| gz_table_to_file.key?(t) }
      missing = referenced_table_names - to_import_as_vector - to_import_as_table

      if missing.any?
        puts "WARNING: The following table(s) are referenced by layers but NOT found on S3:"
        missing.each { |t| puts "  ✗  #{t}" }
        puts ""
      end

      puts "Import plan:"
      puts "  Vectors  (.gpkg)     : #{to_import_as_vector.size}"
      puts "  Non-spatial (.csv.gz): #{to_import_as_table.size}"
      puts "  Missing (not on S3)  : #{missing.size}"
      puts ""

      if to_import_as_vector.empty? && to_import_as_table.empty?
        puts "Nothing to import."
        next
      end

      # ── 3. Ensure the target schema exists ────────────────────────────────

      if target_schema != "public"
        ar_conn.execute("CREATE SCHEMA IF NOT EXISTS \"#{target_schema}\"")
        puts "Ensured schema '#{target_schema}' exists."
      end

      # ── 4. Import vectors (.gpkg via ogr2ogr) ─────────────────────────────

      imported_vectors = []
      skipped_vectors = []
      failed_vectors = []

      total_vectors = to_import_as_vector.size
      to_import_as_vector.each_with_index do |tbl, idx|
        basename = gpkg_table_to_file[tbl]
        info = CartodbRakeHelpers.parse_vector_filename(basename)
        q_table = "\"#{target_schema}\".\"#{tbl}\""

        exists = begin
          ar_conn.table_exists?("#{target_schema}.#{tbl}")
        rescue ActiveRecord::ConnectionFailed, ActiveRecord::DatabaseConnectionError, PG::Error => e
          warn "  DB connection lost before checking #{tbl} (#{e.message}) — reconnecting..."
          sleep 30
          begin
            ActiveRecord::Base.connection_pool.disconnect!
            ar_conn = ActiveRecord::Base.connection
            raw_conn = ar_conn.raw_connection rescue nil
          rescue => reconnect_err
            warn "  Reconnect attempt failed: #{reconnect_err.message}. Waiting 30s..."
            sleep 30
          end
          retry
        end

        if exists
          if force
            puts "\n  Table #{q_table} already exists — overwriting (FORCE=1)."
          else
            puts "  Skipping #{tbl} (already exists; set FORCE=1 to overwrite)."
            skipped_vectors << tbl
            next
          end
        end

        puts "\nImporting vector [#{idx + 1}/#{total_vectors}]: #{basename} → #{q_table} ..."

        local_path = File.join(tmpdir, basename)
        print "  Downloading from S3... "
        unless system("aws s3 cp \"s3://#{s3_bucket}/#{vectors_prefix}#{basename}\" \"#{local_path}\"")
          warn "  FAILED: S3 download failed."
          failed_vectors << {table: tbl, file: basename, reason: "S3 download failed"}
          next
        end
        puts "  done (#{File.size(local_path)} bytes)."

        puts "  Running ogr2ogr..."
        success = system(
          "ogr2ogr", "-f", "PostgreSQL",
          "PG:#{pg_conn}",
          local_path,
          "-nln", "#{target_schema}.#{tbl}",
          "-overwrite",
          "-nlt", "PROMOTE_TO_MULTI",
          "-gt", "100",
          "--config", "PG_USE_COPY", "YES"
        )

        unless success
          warn "  FAILED: ogr2ogr returned non-zero exit code."
          failed_vectors << {table: tbl, file: basename, reason: "ogr2ogr failed"}
          File.delete(local_path) rescue nil
          # PostgreSQL may have crashed (OOM). Wait and retry until PG recovers.
          warn "  Waiting for PostgreSQL to recover..."
          sleep 30
          10.times do |attempt|
            begin
              ActiveRecord::Base.connection_pool.disconnect!
              ar_conn = ActiveRecord::Base.connection
              ar_conn.execute("SELECT 1")
              raw_conn = ar_conn.raw_connection rescue nil
              warn "  Reconnected (attempt #{attempt + 1})."
              break
            rescue => e
              if attempt < 9
                warn "  PG not ready yet (attempt #{attempt + 1}/10): #{e.message}. Waiting 15s..."
                sleep 15
              else
                warn "  Reconnect failed after all attempts: #{e.message} — subsequent tables may not import."
              end
            end
          end
          next
        end

        row_count = begin
          ar_conn.select_value("SELECT count(*) FROM #{q_table}").to_i
        rescue
          0
        end
        puts "  #{row_count} feature(s) loaded."
        imported_vectors << {file: basename, src_schema: info[:schema], table: tbl, rows: row_count}

        # Remove local copy to free disk space in the temp directory
        begin
          File.delete(local_path)
        rescue
          nil
        end
      end

      # ── 5. Import non-spatial tables (.csv.gz via COPY) ───────────────────

      imported_tables = []
      skipped_tables = []
      failed_tables = []

      # Load manifest for better schema/table name inference
      manifest_path = if use_s3
        local_m = File.join(tmpdir, "tables.csv")
        local_m if system("aws s3 cp \"s3://#{s3_bucket}/#{tables_prefix}tables.csv\" \"#{local_m}\" 2>/dev/null")
      elsif export_dir.present?
        File.join(export_dir, "tables.csv")
      end

      manifest = CartodbRakeHelpers.load_manifest(manifest_path)
      puts "Loaded manifest with #{manifest.size} entry(ies)." if manifest.any?

      total_tables = to_import_as_table.size
      to_import_as_table.each_with_index do |tbl, idx|
        basename = gz_table_to_file[tbl]
        info = manifest[basename] || CartodbRakeHelpers.parse_export_filename(basename)
        unless info
          warn "  SKIP #{basename}: cannot parse schema/table from filename."
          skipped_tables << basename
          next
        end

        src_schema = info[:schema]
        q_table = "\"#{target_schema}\".\"#{tbl}\""

        if ar_conn.table_exists?("#{target_schema}.#{tbl}")
          if force
            puts "\n  Table #{q_table} already exists — overwriting (FORCE=1)."
          else
            puts "  Skipping #{tbl} (already exists; set FORCE=1 to overwrite)."
            skipped_tables << basename
            next
          end
        end

        puts "\nImporting table [#{idx + 1}/#{total_tables}]: #{basename} → #{q_table} (original schema: #{src_schema})..."

        gz_path = if use_s3
          local_path = File.join(tmpdir, basename)
          print "  Downloading from S3... "
          unless system("aws s3 cp \"s3://#{s3_bucket}/#{tables_prefix}#{basename}\" \"#{local_path}\"")
            warn "FAILED."
            failed_tables << {file: basename, reason: "S3 download failed"}
            next
          end
          puts "done (#{File.size(local_path)} bytes compressed)."
          local_path
        else
          File.join(export_dir, basename)
        end

        unless File.exist?(gz_path) && File.size(gz_path) > 0
          warn "  FAILED: file not found or empty: #{gz_path}"
          failed_tables << {file: basename, reason: "file not found or empty"}
          next
        end

        # ── Infer column types from a sample of up to 1,000 rows ─────────

        print "  Inferring column types... "
        col_types = CartodbRakeHelpers.infer_column_types(gz_path, limit: 1_000)
        if col_types.empty?
          warn "FAILED (no columns found in CSV)."
          failed_tables << {file: basename, reason: "no columns in CSV"}
          next
        end
        puts "#{col_types.size} column(s) detected."

        # ── Create (or replace) the target table ──────────────────────────

        ar_conn.execute("DROP TABLE IF EXISTS #{q_table}")
        col_defs = col_types.map { |col, type| "\"#{col}\" #{type}" }.join(", ")
        ar_conn.execute("CREATE TABLE #{q_table} (#{col_defs})")

        # ── Stream decompressed CSV directly into COPY FROM STDIN ─────────

        print "  Loading rows... "
        begin
          raw_conn.copy_data(
            "COPY #{q_table} FROM STDIN WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', NULL '')"
          ) do
            Zlib::GzipReader.open(gz_path) do |gz|
              buf = "".b  # binary buffer reused each iteration
              raw_conn.put_copy_data(buf) while gz.read(65_536, buf)
            end
          end

          row_count = ar_conn.select_value("SELECT count(*) FROM #{q_table}").to_i
          puts "#{row_count} row(s) loaded."
          imported_tables << {file: basename, src_schema: src_schema, table: tbl, rows: row_count}
        rescue => e
          warn "FAILED: #{e.message}"
          ar_conn.execute("DROP TABLE IF EXISTS #{q_table}")
          failed_tables << {file: basename, reason: e.message}
        end
      end

      # ── 6. Summary ────────────────────────────────────────────────────────

      puts "\n#{"=" * 60}"
      puts "  CartoDB Import — Summary"
      puts "=" * 60

      total_imported = imported_vectors.size + imported_tables.size
      total_failed = failed_vectors.size + failed_tables.size
      total_skipped = skipped_vectors.size + skipped_tables.size

      puts "  Imported : #{total_imported}"
      imported_vectors.each { |t| puts "    ✓  #{t[:src_schema]}.#{t[:table]} → #{target_schema}.#{t[:table]}  [vector, #{t[:rows]} features]" }
      imported_tables.each { |t| puts "    ✓  #{t[:src_schema]}.#{t[:table]} → #{target_schema}.#{t[:table]}  [table, #{t[:rows]} rows]" }

      if missing.any?
        puts "  Not on S3: #{missing.size}"
        missing.each { |t| puts "    ✗  #{t}" }
      end

      if total_skipped > 0
        puts "  Skipped  : #{total_skipped}"
        skipped_vectors.each { |t| puts "    –  #{t}" }
        skipped_tables.each { |f| puts "    –  #{f}" }
      end

      if total_failed > 0
        puts "  Failed   : #{total_failed}"
        failed_vectors.each { |f| puts "    ✗  #{f[:table]} (#{f[:file]}): #{f[:reason]}" }
        failed_tables.each { |f| puts "    ✗  #{f[:file]}: #{f[:reason]}" }
        abort "\nERROR: #{total_failed} table(s) failed to import — see above."
      end

      puts ""
      puts "Run `rake cartodb:update_layer_references` to update the formerly CartoDB layer rows."
    end
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Update formerly CartoDB layer rows to reference the tables imported by import_tables.

    For each layer flagged by the FlagCartodbLayersForReview migration
    (layer_provider=NULL, published=false, query present) this task:

      1. Parses the CartoDB SQL query to discover referenced table names.
      2. Checks which of those tables now exist in the local PostgreSQL database.
      3. Updates layer_config with a "cartodb_migration" block that records each
         table's import status ("imported" or "missing") and the recommended next steps.
      4. Rewrites the "query" field to strip CartoDB-internal columns
         (cartodb_id, the_geom_webmercator, the_geom) so the SQL is valid against
         the local tables once a new layer_provider is configured.

    Layers remain unpublished (published=false) after this task.  The operator must
    set a valid layer_provider and finalize layer_config in the admin UI before
    re-publishing.

    Optional:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema where tables were imported (default: public)

    Usage:
      rake cartodb:update_layer_references
  DESC
  task update_layer_references: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")

    formerly_cartodb = Layer
      .where(layer_provider: nil, published: false)
      .where.not(query: [nil, ""])
      .order(:id)

    if formerly_cartodb.empty?
      puts "No formerly CartoDB layers found " \
           "(layer_provider=NULL, published=false, query present).  Nothing to do."
      next
    end

    puts "Found #{formerly_cartodb.count} formerly CartoDB layer(s).\n\n"

    ar_conn = ActiveRecord::Base.connection
    updated = []
    needs_import = []
    no_tables = []

    formerly_cartodb.each do |layer|
      puts "Layer ##{layer.id} (#{layer.slug}):"

      # ── Parse table names from the CartoDB SQL ─────────────────────────

      referenced = CartodbRakeHelpers.extract_table_names_from_sql(layer.query)

      if referenced.empty?
        puts "  ⚠  No FROM/JOIN table references found in query — skipping."
        no_tables << {id: layer.id, slug: layer.slug}
        next
      end

      puts "  Referenced tables : #{referenced.join(", ")}"

      # ── Check which tables are now available locally ────────────────────

      local_tables = referenced.select { |t| ar_conn.table_exists?("#{target_schema}.#{t}") }
      missing_tables = referenced - local_tables

      puts "  Available locally : #{local_tables.any? ? local_tables.join(", ") : "(none)"}"
      puts "  Still missing     : #{missing_tables.any? ? missing_tables.join(", ") : "(none)"}"

      # ── Build the cartodb_migration block for layer_config ─────────────

      table_status = referenced.each_with_object({}) do |t, h|
        h[t] = local_tables.include?(t) ? "imported" : "missing"
      end

      migration_block = {
        "status" => local_tables.any? ? "partial" : "pending",
        "tables" => table_status,
        "note" => "Set layer_provider and update layer_config, then set published=true."
      }

      # Merge into the existing layer_config JSON (or start fresh)
      existing_config = begin
        layer.layer_config.present? ? JSON.parse(layer.layer_config) : {}
      rescue JSON::ParserError
        {}
      end

      new_config = existing_config.merge("cartodb_migration" => migration_block)

      # ── Strip CartoDB-internal columns from the query ───────────────────

      cleaned_query = CartodbRakeHelpers.strip_cartodb_columns(layer.query)

      # ── Persist via update_columns to bypass model validations ─────────
      # (layer_provider=NULL fails presence validation; we must go around it)

      layer.update_columns(
        layer_config: new_config.to_json,
        query: cleaned_query
      )

      if local_tables.any?
        puts "  ✓  Updated layer_config and cleaned query."
        updated << {id: layer.id, slug: layer.slug, local: local_tables, missing: missing_tables}
      else
        puts "  ⚠  No referenced tables imported yet — layer_config updated with pending status."
        needs_import << {id: layer.id, slug: layer.slug, missing: missing_tables}
      end
    end

    # ── Summary ─────────────────────────────────────────────────────────────

    puts "\n#{"=" * 56}"
    puts "  Layer Reference Update — Summary"
    puts "=" * 56

    puts "  Updated (≥1 table available): #{updated.size}"
    updated.each do |l|
      puts "    ✓  ##{l[:id]} #{l[:slug]}"
      puts "       Available : #{l[:local].join(", ")}"
      puts "       Missing   : #{l[:missing].join(", ")}" if l[:missing].any?
    end

    if needs_import.any?
      puts "  Pending import (no tables yet): #{needs_import.size}"
      needs_import.each { |l| puts "    ⚠  ##{l[:id]} #{l[:slug]}  — missing: #{l[:missing].join(", ")}" }
    end

    if no_tables.any?
      puts "  No table references found in query: #{no_tables.size}"
      no_tables.each { |l| puts "    ?  ##{l[:id]} #{l[:slug]}" }
    end

    puts ""
    puts "Next steps:"
    puts "  1. For any still-missing tables, re-run rake cartodb:import_tables,"
    puts "     then re-run this task to refresh status."
    puts "  2. For each updated layer, open the admin UI and:"
    puts "       a. Set layer_provider (e.g. martin, wms, cog)"
    puts "       b. Set layer_config to the appropriate JSON for that provider"
    puts "       c. Set published=true when ready"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Full CartoDB table migration: run import_tables then update_layer_references in sequence.

    Accepts all environment variables from both sub-tasks:
      CARTODB_S3_BUCKET, CARTODB_EXPORT_DIR, CARTODB_S3_PREFIX,
      CARTODB_IMPORT_SCHEMA, FORCE

    Usage:
      rake cartodb:migrate_tables CARTODB_S3_BUCKET=my-bucket
  DESC
  task migrate_tables: ["cartodb:import_tables", "cartodb:update_layer_references"]

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Show the current migration status of formerly CartoDB layers and their referenced tables.

    Optional:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema to check for imported tables (default: public)

    Usage:
      rake cartodb:status
  DESC
  task status: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "public")
    ar_conn = ActiveRecord::Base.connection

    formerly_cartodb = Layer
      .where(layer_provider: nil, published: false)
      .where.not(query: [nil, ""])
      .order(:id)

    total_null = Layer.where(layer_provider: nil).count

    puts "=== CartoDB Migration Status (#{Time.current.strftime("%Y-%m-%d %H:%M")}) ==="
    puts ""
    puts "  Layers with provider=NULL             : #{total_null}"
    puts "  of which unpublished with query (flagged): #{formerly_cartodb.count}"
    puts ""

    if formerly_cartodb.empty?
      puts "No formerly CartoDB layers remain.  Migration appears complete."
      next
    end

    all_ready = 0
    partial = 0
    pending = 0

    formerly_cartodb.each do |layer|
      referenced = CartodbRakeHelpers.extract_table_names_from_sql(layer.query)
      next if referenced.empty?

      statuses = referenced.map do |t|
        [t, ar_conn.table_exists?("#{target_schema}.#{t}") ? :available : :missing]
      end.to_h

      all_avail = statuses.values.all? { |s| s == :available }
      any_avail = statuses.values.any? { |s| s == :available }

      icon = if all_avail
        "✓"
      else
        (any_avail ? "~" : "✗")
      end

      if all_avail
        all_ready += 1
      elsif any_avail
        partial += 1
      else
        pending += 1
      end

      puts "  #{icon} ##{layer.id} #{layer.slug}"
      statuses.each do |t, s|
        puts "      #{(s == :available) ? "✓" : "✗"} #{target_schema}.#{t}  (#{s})"
      end
    end

    puts ""
    puts "  All tables imported : #{all_ready}"
    puts "  Partial             : #{partial}"
    puts "  No tables yet       : #{pending}"
    puts ""
    puts "Run `rake cartodb:migrate_tables` to import tables and update layer references."
  end
end
