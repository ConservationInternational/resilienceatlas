require "csv"
require "tempfile"
require "fileutils"

# Background job that streams a large CSV from S3 and batch-inserts
# rows into a ScopeDataset's data column.
#
# Queue: imports
class CsvImportJob
  include Sidekiq::Job

  sidekiq_options queue: :imports, retry: 2

  BATCH_SIZE = 1_000

  def perform(data_import_id)
    di = DataImport.find(data_import_id)
    scope_dataset = di.importable
    raise ArgumentError, "importable must be a ScopeDataset" unless scope_dataset.is_a?(ScopeDataset)

    di.update!(status: "processing", started_at: Time.current)

    work_dir   = Rails.root.join("tmp", "imports", data_import_id.to_s)
    FileUtils.mkdir_p(work_dir)
    local_path = work_dir.join(di.file_name.presence || "import.csv").to_s

    begin
      download_from_s3(di.s3_key, local_path)

      all_rows   = []
      row_count  = 0
      batch      = []

      CSV.foreach(local_path, headers: true, converters: :numeric) do |row|
        batch << row.to_h
        row_count += 1

        if batch.size >= BATCH_SIZE
          all_rows.concat(batch)
          batch = []
        end
      end
      all_rows.concat(batch) unless batch.empty?

      scope_dataset.update!(data: all_rows)

      di.update!(
        status: "complete",
        rows_imported: row_count,
        completed_at: Time.current
      )
    rescue CSV::MalformedCSVError => e
      di.update!(
        status: "failed",
        error_message: "CSV parse error: #{e.message}",
        completed_at: Time.current
      )
      raise
    rescue => e
      di.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}",
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
      region:            ENV.fetch("AWS_REGION", "us-east-1"),
      access_key_id:     ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    )
    client.get_object(
      bucket: ENV.fetch("S3_BUCKET", "resilienceatlas"),
      key: s3_key,
      response_target: local_path
    )
  end
end
