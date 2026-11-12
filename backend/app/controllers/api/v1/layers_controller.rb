module Api
  module V1
    class LayersController < ApiController
      before_action :authenticate_request, only: :download_attachments
      include SitesFilters
      before_action :set_layer, only: :download_attachments

      def index
        @layers = Layer.fetch_all(layers_params).includes :agrupations, sources: :translations, layer_groups: [:translations, super_group: :translations]
        response.cache_control.replace(private: true, no_store: true)
        render json: @layers, meta: {total_layers: @layers.size}, include: ["layer_groups", "sources"], site_scope: layers_params[:site_scope].to_i
      end

      def download_attachments
        UserDownload.create(layer: @layer, user_id: current_user&.id, subdomain: @subdomain)
        zipped = @layer.zip_attachments(params, request.original_url.to_s, @site_name, @subdomain)

        if zipped
          send_data zipped[:data], type: "application/zip; charset=UTF-8;", filename: zipped[:filename]
        else
          render json: {message: "No files for specified layer"}
        end
      end

      private

      def set_layer
        @layer = Layer.fetch_all(layers_params).find(params[:id])
      end
    end
  end
end
