require "aws-sdk-s3"

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
      before_action :find_session, except: :create_multipart
      rescue_from ArgumentError, KeyError, ActiveRecord::RecordInvalid do |error|
        Rails.logger.warn "[Uploads] #{error.message}"
        render json: {error: error.message}, status: :bad_request
      end
      rescue_from ActiveRecord::RecordNotFound do
        render json: {error: "Upload session not found"}, status: :not_found
      end
      rescue_from Aws::S3::Errors::ServiceError do |error|
        Rails.logger.error "[Uploads] #{error.class}: #{error.message}"
        render json: {error: error.message}, status: :service_unavailable
      end

      ALLOWED_PREFIXES = %w[cogs staging].freeze
      MAX_PART_COUNT = 10_000

      # POST /api/v1/uploads/multipart
      # Body: { filename, type, metadata: { size } }
      def create_multipart
        filename = sanitize_filename(params[:filename].to_s)
        content_type = params[:type].presence || "application/octet-stream"
        prefix = allowed_prefix(params.dig(:metadata, :prefix).to_s)
        if params.dig(:metadata, :session_id).present?
          @upload = DataImport.find(params.dig(:metadata, :session_id))
          raise ArgumentError, "Invalid upload owner or state" unless @upload.admin_user_id == current_admin_user.id && @upload.uploading? && @upload.managed_upload?
          raise ArgumentError, "File does not match the session" unless filename == sanitize_filename(@upload.file_name) &&
            params.dig(:metadata, :size).to_i == @upload.file_size_bytes
        else
          raise ArgumentError, "Only CSV legacy uploads are supported; use Upload New Data for spatial files" unless %w[.csv .tsv].include?(File.extname(filename).downcase)
          size = params.dig(:metadata, :size).to_i
          raise ArgumentError, "Invalid file size" unless size.between?(1, SpatialUploadLifecycle.max_bytes)
          @upload = DataImport.create!(admin_user: current_admin_user, file_name: filename,
            file_size_bytes: size, import_type: "csv", status: "uploading",
            options: {"workflow" => "legacy_csv"})
        end
        raise ArgumentError, "Not authorized" unless Ability.new(current_admin_user).can?(:manage, DataImport)
        prefix = "staging" if @upload.managed_upload?
        key = "#{prefix}/uploads/#{@upload.id}/#{filename}"

        @upload.with_lock do
          raise ArgumentError, "Upload is no longer active" unless @upload.uploading?
          if @upload.upload_id.blank?
            resp = s3_client.create_multipart_upload(bucket: s3_bucket, key: key, content_type: content_type)
            @upload.update!(upload_id: resp.upload_id, s3_key: key)
          end
        end
        render json: {uploadId: @upload.upload_id, key: @upload.s3_key}
      rescue Aws::S3::Errors::ServiceError => e
        render json: {error: e.message}, status: :service_unavailable
      end

      # GET /api/v1/uploads/multipart/:upload_id?key=...&partNumbers[]=...
      def sign_parts
        upload_id = params[:upload_id]
        key = validate_key!(params[:key])
        raise ArgumentError, "Upload is no longer active" unless @upload.uploading?
        if params[:list] == "1"
          parts = []
          marker = nil
          loop do
            result = s3_client.list_parts(bucket: s3_bucket, key: key, upload_id: upload_id, part_number_marker: marker)
            parts.concat(result.parts.map { |part| {PartNumber: part.part_number, ETag: part.etag, Size: part.size} })
            break unless result.is_truncated
            marker = result.next_part_number_marker
          end
          render json: {parts: parts}
          return
        end
        part_numbers = Array(params[:partNumbers]).map { |number| Integer(number) }
        raise ArgumentError, "Invalid part numbers" unless part_numbers.any? && part_numbers.size <= MAX_PART_COUNT &&
          part_numbers.all? { |number| number.between?(1, MAX_PART_COUNT) }

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
        @upload.with_lock do
          raise ArgumentError, "Upload was cancelled" if @upload.cancelled?
          if @upload.metadata["transferred"]
            render json: {location: "s3://#{s3_bucket}/#{key}"}
            return
          end
          raise ArgumentError, "Missing upload parts" unless params[:parts].is_a?(Array) && params[:parts].any? && params[:parts].size <= MAX_PART_COUNT
          parts = params[:parts].map do |part|
            {part_number: part[:PartNumber].to_i, etag: part[:ETag]}
          end
          raise ArgumentError, "Invalid upload parts" unless parts.map { |part| part[:part_number] } == (1..parts.size).to_a &&
            parts.all? { |part| part[:etag].present? }

          begin
            s3_client.complete_multipart_upload(
              bucket: s3_bucket,
              key: key,
              upload_id: upload_id,
              multipart_upload: {parts: parts}
            )
          rescue Aws::S3::Errors::NoSuchUpload
            Rails.logger.warn "[Upload #{@upload.id}] Multipart already closed; verifying stored object before recovery"
          end
          actual = s3_client.head_object(bucket: s3_bucket, key: key)
          raise ArgumentError, "Stored file size does not match" unless actual.content_length == @upload.file_size_bytes
          @upload.update!(metadata: @upload.metadata.merge("transferred" => true),
            stage: "File transfer complete", status: @upload.managed_upload? ? "uploading" : "ready")

          render json: {location: "s3://#{s3_bucket}/#{key}"}
        end
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
        @upload.update!(status: "cancelled", stage: "Cancelled", completed_at: Time.current)

        head :no_content
      rescue Aws::S3::Errors::ServiceError => e
        render json: {error: e.message}, status: :service_unavailable
      end

      private

      def find_session
        @upload = DataImport.find_by!(upload_id: params[:upload_id], s3_key: params[:key], admin_user: current_admin_user)
        raise ArgumentError, "Not authorized" unless Ability.new(current_admin_user).can?(:manage, DataImport)
        raise ArgumentError, "Upload is no longer active" if @upload.cancelled?
        raise ArgumentError, "Upload is no longer active" unless @upload.uploading? || @upload.ready? || @upload.metadata["transferred"]
      end

      def s3_client
        @s3_client ||= Aws::S3::Client.new(region: ENV.fetch("AWS_REGION", "us-east-1"))
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
