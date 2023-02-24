module Api
  module V1
    class LayersController < ApiController
      # before_action :authenticate_user!, only: :download_attachments
      before_action :set_layer, only: :download_attachments

      include SitesFilters

      def index
        @layers = Layer.fetch_all(layers_params)
        render json: @layers, meta:{total_layers: @layers.size}, include: ['layer_groups', 'sources'], site_scope: layers_params[:site_scope].to_i
      end

      def download_attachments
        UserDownload.create(layer: @layer, user_id: params[:user_id], subdomain: @subdomain)
        zipped = @layer.zip_attachments(params, "#{request.original_url}", @site_name, @subdomain)

        if zipped
          File.open(zipped, 'r') do |f|
            send_data f.read, type: 'application/zip; charset=UTF-8;', filename: File.basename(zipped)
          end
        else
          render json: { message: "No files for specified layer" }
        end
      end

      private

        def set_layer
          @layer = Layer.find(params[:id])
        end
    end
  end
end
