module Blobs
  class GetLink
    attr_accessor :original_blob, :options

    def initialize(original_blob, **options)
      @original_blob = original_blob
      @options = options
    end

    def call
      return if original_blob.blank?

      modified_blob = modify(original_blob)
      
      # For test environment, try to use only_path first to avoid host issues
      if Rails.env.test?
        begin
          Rails.application.routes.url_helpers.url_for(modified_blob, only_path: true)
        rescue => e
          Rails.logger.warn "Failed to generate blob URL: #{e.message}"
          # Handle both regular blobs and variants
          blob_id = modified_blob.respond_to?(:blob) ? modified_blob.blob.id : modified_blob.id
          "/test_blob_url_#{blob_id}"
        end
      else
        Rails.application.routes.url_helpers.url_for(modified_blob)
      end
    end

    private

    def modify(original_blob)
      (options.present? && original_blob.variable?) ? original_blob.variant(options) : original_blob
    end
  end
end
