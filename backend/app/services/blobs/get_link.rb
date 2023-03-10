module Blobs
  class GetLink
    attr_accessor :original_blob, :options

    def initialize(original_blob, **options)
      @original_blob = original_blob
      @options = options
    end

    def call
      return if original_blob.blank?

      Rails.application.routes.url_helpers.url_for modify(original_blob)
    end

    private

    def modify(original_blob)
      options.present? ? original_blob.variant(options) : original_blob
    end
  end
end
