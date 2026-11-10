# Compatibility for jobs already queued before the upload-workspace rollout.
class VectorImportJob
  include Sidekiq::Job
  sidekiq_options queue: :imports, retry: false

  def perform(id)
    di = DataImport.find(id)
    return if di.complete? || di.cancelled?
    di.with_lock do
      di.update!(status: "pending", target_updated_at: di.importable&.updated_at,
        options: di.options.merge("workflow" => "spatial_upload", "mode" => di.importable.is_a?(Layer) ? "replace" : "dataset"),
        metadata: di.metadata.merge("transferred" => true))
    end
    SpatialUploadJob.new.perform(id)
  end
end
