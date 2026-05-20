require "open3"
require "tempfile"
require "fileutils"

# Background job that downloads a spatial file from S3 and imports it into
# the ra_vector PostgreSQL schema via ogr2ogr, then configures the layer
# for Martin tile serving.
#
# Queue: imports (separate from default to avoid blocking other jobs)
class VectorImportJob
  include Sidekiq::Job

  sidekiq_options queue: :imports, retry: 2

  # Column names that Martin / the popup should ignore
  SKIP_COLS = LayerInteractionConfigBuilder::SKIP_COLS
  TARGET_SCHEMA = "ra_vector"

  def perform(data_import_id)
    di = DataImport.find(data_import_id)
    layer = di.importable
    raise ArgumentError, "importable must be a Layer" unless layer.is_a?(Layer)

    di.update!(status: "processing", started_at: Time.current)

    s3_key = di.s3_key
    file_name = di.file_name.presence || File.basename(s3_key)
    table_name = "imported_#{layer.slug.gsub(/[^a-z0-9_]/, "_")}"

    work_dir = Rails.root.join("tmp", "imports", data_import_id.to_s)
    FileUtils.mkdir_p(work_dir)
    local_path = work_dir.join(file_name).to_s

    begin
      # 1. Download from S3
      download_from_s3(s3_key, local_path)

      # 2. Import via ogr2ogr into ra_vector schema
      ogr2ogr_import!(local_path, table_name)

      # 3. Create GiST spatial index (required for efficient tile queries)
      create_spatial_index(table_name)

      # 4. Build interaction_config from PostGIS column names
      conn = ActiveRecord::Base.connection
      ic = LayerInteractionConfigBuilder.for_martin(table_name, conn, TARGET_SCHEMA)

      # 5. Update the Layer record
      # Use the ra_vector_tile function source so Martin serves the layer
      # immediately without needing a restart to discover the new table.
      new_config = {"body" => {"source" => "ra_vector_tile", "params" => {"table" => table_name}}}
      update_attrs = {
        layer_provider: "martin",
        layer_config: new_config.to_json
      }
      update_attrs[:interaction_config] = ic.to_json if ic
      layer.update_columns(**update_attrs)

      di.update!(
        status: "complete",
        completed_at: Time.current
      )
    rescue => e
      di.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}",
        completed_at: Time.current
      )
      raise # re-raise so Sidekiq retry logic fires
    ensure
      FileUtils.rm_rf(work_dir)
    end
  end

  private

  def download_from_s3(s3_key, local_path)
    bucket = ENV.fetch("S3_BUCKET", "resilienceatlas")
    region = ENV.fetch("AWS_REGION", "us-east-1")

    client = Aws::S3::Client.new(
      region: region,
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    )

    client.get_object(bucket: bucket, key: s3_key, response_target: local_path)
  end

  def ogr2ogr_import!(local_path, table_name)
    db_url = build_pg_url
    cmd = [
      "ogr2ogr",
      "-f", "PostgreSQL",
      "PG:#{db_url}",
      local_path,
      "-nln", "#{TARGET_SCHEMA}.#{table_name}",
      "-nlt", "PROMOTE_TO_MULTI",
      "-t_srs", "EPSG:4326",
      "-overwrite",
      "--config", "OGR_TRUNCATE", "YES"
    ]

    stdout, stderr, status = Open3.capture3(*cmd)
    unless status.success?
      raise "ogr2ogr failed (exit #{status.exitstatus}):\n#{stderr}"
    end
    Rails.logger.info "VectorImportJob ogr2ogr: #{stdout}" if stdout.present?
  end

  def create_spatial_index(table_name)
    conn = ActiveRecord::Base.connection

    geom_cols = conn.execute(
      "SELECT f_geometry_column FROM geometry_columns " \
      "WHERE f_table_schema = '#{TARGET_SCHEMA}' AND f_table_name = '#{table_name}'"
    ).map { |r| r["f_geometry_column"] }

    geom_cols.each do |col|
      idx_name = "idx_#{table_name}_#{col}"[0, 63]
      conn.execute(
        "CREATE INDEX IF NOT EXISTS #{conn.quote_table_name(idx_name)} " \
        "ON \"#{TARGET_SCHEMA}\".\"#{table_name}\" " \
        "USING GIST (\"#{col}\")"
      )
    end
  end

  def build_pg_url
    cfg = ActiveRecord::Base.connection_db_config.configuration_hash
    host = cfg[:host] || "localhost"
    port = cfg[:port] || 5432
    dbname = cfg[:database]
    user = cfg[:username]
    password = cfg[:password]
    "host=#{host} port=#{port} dbname=#{dbname} user=#{user} password=#{password}"
  end
end
