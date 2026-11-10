namespace :uploads do
  desc "Reconcile interrupted upload jobs and abort abandoned multipart transfers (does not delete datasets)"
  task reconcile: :environment do
    upload_cutoff = Integer(ENV.fetch("UPLOAD_SESSION_RETENTION_HOURS", "168")).hours.ago
    processing_cutoff = (Integer(ENV.fetch("UPLOAD_PROCESSING_TIMEOUT_SECONDS", "1800")) + 600).seconds.ago
    DataImport.where(status: "uploading").where("updated_at < ?", upload_cutoff).find_each do |di|
      next unless di.managed_upload? || di.options["workflow"] == "legacy_csv"
      di.with_lock do
        next unless di.uploading? && di.updated_at < upload_cutoff
        UploadStorage.new.abort(di)
        di.update!(status: "cancelled", stage: "Abandoned transfer expired", completed_at: Time.current)
        Rails.logger.info "[Upload #{di.id}] Expired abandoned transfer"
      end
    end
    DataImport.where(status: %w[pending processing]).where("updated_at < ?", processing_cutoff).find_each do |di|
      next unless di.managed_upload?
      di.with_lock do
        next unless di.pending? || di.processing?
        next unless di.updated_at < processing_cutoff
        di.update!(status: "failed", stage: "Worker interrupted or unavailable",
          error_message: "Processing did not finish within the configured budget. Check worker health before retrying.",
          completed_at: Time.current)
        Rails.logger.error "[Upload #{di.id}] Reconciled stale worker state"
      end
    end
  end
end
