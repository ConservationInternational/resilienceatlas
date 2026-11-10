require "fileutils"
require "timeout"

class SpatialUploadJob
  include Sidekiq::Job
  sidekiq_options queue: :imports, retry: false

  def perform(id)
    di = DataImport.find(id)
    claimed = di.with_lock do
      next false unless di.pending?
      di.update!(status: "processing", stage: "Inspecting and processing", started_at: Time.current,
        attempts: di.attempts + 1, error_message: nil)
      true
    end
    return unless claimed
    attempt = di.attempts

    work_dir = Rails.root.join("tmp", "imports", "upload-#{id}-#{SecureRandom.hex(6)}")
    FileUtils.mkdir_p(work_dir)
    storage = UploadStorage.new
    local_path = work_dir.join(File.basename(di.file_name))
    storage.download(di.s3_key, local_path)
    raise "Uploaded object size does not match the declared size" unless File.size(local_path) == di.file_size_bytes

    processor = di.type_vector? ? VectorUploadProcessor : RasterUploadProcessor
    result = Timeout.timeout(Integer(ENV.fetch("UPLOAD_PROCESSING_TIMEOUT_SECONDS", "1800"))) do
      processor.new(di, work_dir: work_dir, storage: storage).call(local_path.to_s)
    end
    di.with_lock do
      next unless di.processing? && di.attempts == attempt
      di.update!(status: "ready", stage: "Ready for configuration and preview",
        metadata: result.merge("transferred" => true), rows_imported: result["rows"], completed_at: Time.current)
    end
  rescue UploadSelectionRequired => e
    di.with_lock do
      if di.processing? && di.attempts == attempt
        di.update!(status: "needs_input", stage: "Input required", metadata: e.metadata.merge("transferred" => true),
          error_message: e.message)
      end
    end
  rescue => e
    Rails.logger.error "[Upload #{id}] #{e.class}: #{e.message}"
    Rollbar.error(e, data_import_id: id) if defined?(Rollbar)
    di&.with_lock do
      if di.processing? && di.attempts == attempt
        di.update!(status: "failed", stage: "Processing failed", error_message: e.message.truncate(4000),
          completed_at: Time.current)
      end
    end
    raise
  ensure
    FileUtils.remove_entry(work_dir) if work_dir&.directory?
  end
end
