module Api
  module V1
    # Handles presigned S3 multipart upload coordination.
    # All endpoints require an authenticated AdminUser session or token.
    #
    # Clients (Uppy @uppy/aws-s3-multipart) interact with:
    #   POST   /api/v1/uploads/multipart                 - create upload
    #   GET    /api/v1/uploads/multipart/:upload_id      - list/sign parts
    #   GET    /api/v1/uploads/multipart/:upload_id/batch - batch sign parts
    #   POST   /api/v1/uploads/multipart/:upload_id/complete - complete
    #   DELETE /api/v1/uploads/multipart/:upload_id     - abort
    class UploadsController < ApplicationController
      before_action :authenticate_admin_user!

      ALLOWED_PREFIXES = %w[cogs staging].freeze
      MAX_PART_COUNT = 10_000

      # POST /api/v1/uploads/multipart
      # Body: { filename, type, metadata: { size } }
      def create_multipart
        filename = sanitize_filename(params[:filename].to_s)
        content_type = params[:type].presence || "application/octet-stream"
        prefix = allowed_prefix(params.dig(:metadata, :prefix).to_s)

        key = "#{prefix}/#{SecureRandom.uuid}/#{filename}"

        resp = s3_client.create_multipart_upload(
          bucket: s3_bucket,
          key: key,
          content_type: content_type
        )

        render json: {uploadId: resp.upload_id, key: key}
      rescue Aws::S3::Errors::ServiceError => e
        render json: {error: e.message}, status: :service_unavailable
      end

      # GET /api/v1/uploads/multipart/:upload_id?key=...&partNumbers[]=...
      def sign_parts
        upload_id = params[:upload_id]
        key = validate_key!(params[:key])
        part_numbers = Array(params[:partNumbers]).map(&:to_i).first(MAX_PART_COUNT)

        presigned_urls = part_numbers.index_with do |part_number|
          s3_presigner.presigned_url(
            :upload_part,
            bucket: s3_bucket,
            key: key,
            upload_id: upload_id,
            part_number: part_number,
            expires_in: 3600
          )
        end

        render json: {presignedUrls: presigned_urls}
      rescue ArgumentError => e
        render json: {error: e.message}, status: :bad_request
      end

      # GET /api/v1/uploads/multipart/:upload_id/batch?key=...&partNumbers[]=...
      # Alias for sign_parts (some Uppy versions use this endpoint)
      alias_method :batch_sign_parts, :sign_parts

      # POST /api/v1/uploads/multipart/:upload_id/complete
      # Body: { key, parts: [{ PartNumber, ETag }, ...] }
      def complete_multipart
        upload_id = params[:upload_id]
        key = validate_key!(params[:key])
        parts = params[:parts].map do |part|
          {part_number: part[:PartNumber].to_i, etag: part[:ETag]}
        end

        s3_client.complete_multipart_upload(
          bucket: s3_bucket,
          key: key,
          upload_id: upload_id,
          multipart_upload: {parts: parts}
        )

        render json: {location: "s3://#{s3_bucket}/#{key}"}
      rescue Aws::S3::Errors::ServiceError => e
        render json: {error: e.message}, status: :service_unavailable
      end

      # DELETE /api/v1/uploads/multipart/:upload_id?key=...
      def abort_multipart
        upload_id = params[:upload_id]
        key = validate_key!(params[:key])

        s3_client.abort_multipart_upload(
          bucket: s3_bucket,
          key: key,
          upload_id: upload_id
        )

        head :no_content
      rescue Aws::S3::Errors::ServiceError => e
        render json: {error: e.message}, status: :service_unavailable
      end

      private

      def s3_client
        @s3_client ||= Aws::S3::Client.new(
          region: ENV.fetch("AWS_REGION", "us-east-1"),
          access_key_id: ENV["AWS_ACCESS_KEY_ID"],
          secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
        )
      end

      def s3_presigner
        @s3_presigner ||= Aws::S3::Presigner.new(client: s3_client)
      end

      def s3_bucket
        ENV.fetch("S3_BUCKET", "resilienceatlas")
      end

      # Only allow keys that start with an approved prefix — prevents
      # callers from writing to arbitrary S3 locations.
      def validate_key!(key)
        prefix = key.to_s.split("/").first
        unless ALLOWED_PREFIXES.include?(prefix)
          raise ArgumentError, "Key prefix '#{prefix}' is not allowed"
        end
        key
      end

      def allowed_prefix(requested)
        ALLOWED_PREFIXES.include?(requested) ? requested : "staging"
      end

      def sanitize_filename(filename)
        # Strip path components and null bytes
        File.basename(filename.delete("\x00")).gsub(/[^\w.\-]/, "_")
      end
    end
  end
end
