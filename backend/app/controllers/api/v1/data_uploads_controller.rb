require "aws-sdk-s3"

module Api
  module V1
    class DataUploadsController < ApplicationController
      before_action :authenticate_admin_user!
      before_action :find_upload, except: :create
      rescue_from ArgumentError, KeyError, JSON::ParserError, ActiveRecord::RecordInvalid, with: :invalid_upload
      rescue_from CanCan::AccessDenied do
        render json: {error: "You are not authorized to modify this upload"}, status: :forbidden
      end
      rescue_from ActiveRecord::RecordNotFound do
        render json: {error: "Upload not found"}, status: :not_found
      end
      rescue_from Aws::S3::Errors::ServiceError, SocketError, IOError, Timeout::Error do |error|
        Rails.logger.error "[DataUploads] #{error.class}: #{error.message}"
        render json: {error: error.message}, status: :service_unavailable
      end

      def create
        @upload = SpatialUploadLifecycle.create!(current_admin_user,
          params.permit(:import_type, :file_name, :file_size_bytes, :mode, :layer_id,
            :name, :slug, :raster_kind).to_h)
        render json: payload, status: :created
      end

      def show
        render json: payload
      end

      def process_file
        raise ArgumentError, "Complete the file transfer first" unless @upload.metadata["transferred"]
        SpatialUploadLifecycle.new(@upload).enqueue!
        render json: payload
      end

      def configure
        values = params.permit(*SpatialUploadLifecycle::CONFIG_KEYS.excluding("popup_fields"),
          popup_fields: []).to_h
        if params.key?(:colormap)
          raise ArgumentError, "Colormap must be a JSON string" unless params[:colormap].is_a?(String)
          values["colormap"] = params[:colormap].present? ? JSON.parse(params[:colormap]) : {}
        end
        SpatialUploadLifecycle.new(@upload).configure!(values)
        render json: payload
      end

      def verify
        raise ArgumentError, "Process this dataset first" unless @upload.ready?
        configuration = @upload.options.deep_dup
        UploadTileService.new(@upload).verify!
        @upload.with_lock do
          raise ArgumentError, "Upload state changed; reload the preview" unless @upload.ready? && @upload.options == configuration
          @upload.update!(metadata: @upload.metadata.merge("verified" => true))
        end
        render json: payload
      end

      def finalize
        layer = SpatialUploadLifecycle.new(@upload).finalize!
        render json: payload.merge(layer_url: layer && admin_layer_path(layer))
      end

      def cancel
        @upload.with_lock do
          raise ArgumentError, "A completed upload cannot be cancelled" if @upload.complete?
          UploadStorage.new.abort(@upload)
          @upload.update!(status: "cancelled", stage: "Cancelled", completed_at: Time.current)
        end
        render json: payload
      end

      def rollback
        SpatialUploadLifecycle.new(@upload).rollback!
        render json: payload
      end

      def tile
        raise ArgumentError, "Dataset not ready" unless @upload.ready? || @upload.complete?
        response = UploadTileService.new(@upload).tile(Integer(params[:z]), Integer(params[:x]), Integer(params[:y]))
        send_data response.body, type: @upload.type_vector? ? "application/vnd.mapbox-vector-tile" : "image/png", disposition: "inline"
      end

      def point
        raise ArgumentError, "Dataset not ready" unless @upload.ready? || @upload.complete?
        response = UploadTileService.new(@upload).point(Float(params[:lon]), Float(params[:lat]))
        render json: JSON.parse(response.body)
      end

      private

      def find_upload
        @upload = DataImport.find(params[:id])
        ability = Ability.new(current_admin_user)
        raise CanCan::AccessDenied unless @upload.managed_upload? && @upload.admin_user_id == current_admin_user.id
        raise CanCan::AccessDenied unless ability.can?(:manage, DataImport)
        raise CanCan::AccessDenied if @upload.importable && !ability.can?(:update, @upload.importable)
      end

      def payload
        @upload.reload
        {id: @upload.id, status: @upload.status, stage: @upload.stage, file_name: @upload.file_name,
         file_size_bytes: @upload.file_size_bytes, import_type: @upload.import_type,
         metadata: @upload.metadata, options: @upload.options, error: @upload.error_message,
         upload_id: @upload.upload_id, key: @upload.s3_key,
         configuration: (@upload.ready? || @upload.complete?) ? UploadLayerConfiguration.new(@upload).attributes : nil,
         rollback_available: @upload.previous_configuration.present?,
         layer_url: @upload.importable.is_a?(Layer) ? admin_layer_path(@upload.importable) : nil}
      end

      def invalid_upload(error)
        Rails.logger.warn "[DataUploads] #{error.class}: #{error.message}"
        render json: {error: error.message}, status: :unprocessable_entity
      end
    end
  end
end
