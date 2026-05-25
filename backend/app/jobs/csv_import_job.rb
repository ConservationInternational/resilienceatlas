require "fileutils"

# Background job that streams a CSV from S3 into a ScopeDataset's data column.
#
# Memory strategy: uses PostgreSQL COPY to stream the file line-by-line from
# disk into a typed TEMP TABLE, then builds the JSONB value with a single
# jsonb_agg() UPDATE — O(1) Ruby memory regardless of CSV size.
#
# Queue: imports
class CsvImportJob
  include Sidekiq::Job

  sidekiq_options queue: :imports, retry: 2

  def perform(data_import_id)
    di = DataImport.find(data_import_id)
    scope_dataset = di.importable
    raise ArgumentError, "importable must be a ScopeDataset" unless scope_dataset.is_a?(ScopeDataset)

    di.update!(status: "processing", started_at: Time.current)

    work_dir = Rails.root.join("tmp", "imports", data_import_id.to_s)
    FileUtils.mkdir_p(work_dir)
    local_path = work_dir.join(di.file_name.presence || "import.csv").to_s

    row_count = 0

    begin
      download_from_s3(di.s3_key, local_path)

      # Infer column types by sampling the first 2 000 rows — O(1) memory.
      col_types = CsvColumnTypeInferrer.infer(local_path)
      raise ArgumentError, "CSV has no detectable columns." if col_types.blank?

      conn = ActiveRecord::Base.connection
      temp_table = "csv_staging_#{di.id.to_i}"
      col_defs = col_types.map { |c, t| "#{conn.quote_column_name(c)} #{t}" }.join(", ")

      conn.transaction do
        conn.execute(
          "CREATE TEMP TABLE #{conn.quote_table_name(temp_table)} (#{col_defs}) ON COMMIT DROP"
        )

        # Stream the file line-by-line into PostgreSQL via COPY.
        # Only one line at a time passes through Ruby; the rest lives in PG.
        raw_conn = conn.raw_connection
        raw_conn.copy_data(
          "COPY #{conn.quote_table_name(temp_table)} FROM STDIN WITH (FORMAT csv, HEADER true)"
        ) do
          File.foreach(local_path, encoding: "UTF-8") { |line| raw_conn.put_copy_data(line) }
        end
        row_count = conn.select_value(
          "SELECT COUNT(*) FROM #{conn.quote_table_name(temp_table)}"
        ).to_i

        # Build JSONB entirely in PostgreSQL. The typed temp table ensures numeric
        # and boolean columns produce correct JSON types (42, not "42").
        conn.execute(
          "UPDATE scope_datasets " \
          "SET data = (" \
          "  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) " \
          "  FROM #{conn.quote_table_name(temp_table)} t" \
          ") WHERE id = #{scope_dataset.id.to_i}"
        )
      end

      di.update!(
        status: "complete",
        rows_imported: row_count,
        completed_at: Time.current
      )
    rescue CSV::MalformedCSVError => e
      Rails.logger.error "[CsvImportJob] CSV parse error: #{e.message}"
      di.update!(
        status: "failed",
        error_message: "CSV parse error: #{e.message}",
        completed_at: Time.current
      )
      raise
    rescue => e
      Rails.logger.error "[CsvImportJob] #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
      di.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}",
        completed_at: Time.current
      )
      raise
    ensure
      FileUtils.rm_rf(work_dir)
    end
  end

  private

  def download_from_s3(s3_key, local_path)
    client = Aws::S3::Client.new(
      region: ENV.fetch("AWS_REGION", "us-east-1"),
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    )
    client.get_object(
      bucket: ENV.fetch("S3_BUCKET", "resilienceatlas"),
      key: s3_key,
      response_target: local_path
    )
  end
end
