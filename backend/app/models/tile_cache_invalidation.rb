class TileCacheInvalidation < ApplicationRecord
  belongs_to :layer, optional: true
  validates :status, inclusion: {in: %w[pending submitted completed failed]}
  validate :validate_paths
  after_create_commit :enqueue_if_configured

  def submit!
    with_lock do
      return if status == "completed"
      service = TileCloudfrontInvalidation.new
      if requests.empty?
        submitted = service.submit(paths, "tile-invalidation-#{id}")
        update!(requests: submitted, external_id: submitted.values.join(","), status: "submitted", error_message: nil)
      end
      if requests.all? { |distribution, request_id| service.completed?(distribution, request_id) }
        update!(status: "completed", error_message: nil)
      end
    end
  rescue TileCloudfrontInvalidation::Error => error
    update!(status: "failed", error_message: error.message)
    Rails.logger.error "[TileCacheInvalidation #{id}] #{error.message}"
    raise
  end

  private

  def enqueue_if_configured
    TileCacheInvalidationJob.perform_async(id) if ENV["TILE_CLOUDFRONT_DISTRIBUTION_IDS"].present?
  rescue RedisClient::Error => error
    update_columns(status: "failed", error_message: "Invalidation queue is unavailable")
    Rails.logger.error "[TileCacheInvalidation #{id}] Queue unavailable (#{error.class})"
  end

  def validate_paths
    unless paths.is_a?(Array) && paths.any? && paths.size <= 1000 &&
        paths.all? { |path| path.is_a?(String) && path.start_with?("/") && path.length <= 4000 && !path.match?(/[\r\n]/) }
      errors.add(:paths, "must contain 1 to 1000 absolute CDN paths")
    end
  end
end
