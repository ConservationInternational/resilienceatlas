module Api
  module V1
    class BoundaryTilesController < ApiController
      # Disable locale loading — tiles are language agnostic
      skip_before_action :set_locale

      # GET /api/boundary-tiles/:z/:x/:y.pbf
      #
      # Returns a Mapbox Vector Tile (protobuf) containing admin boundary
      # geometries appropriate for the requested zoom level:
      #   zoom 0-4:  ADM0 (countries)
      #   zoom 5-7:  ADM0 + ADM1 (provinces/states)
      #   zoom 8+:   ADM0 + ADM1 + ADM2 (districts)
      #
      # The response includes a 1-hour public Cache-Control header so that
      # CDNs and browsers can avoid re-fetching identical tiles.
      def show
        z = params[:z].to_i
        x = params[:x].to_i
        y = params[:y].to_i

        tile_data = AdminBoundary.mvt_tile(z, x, y)

        expires_in 1.hour, public: true

        # An empty tile still gets a 200 with an empty body and the correct
        # content type so that the client doesn't retry endlessly.
        send_data tile_data,
          type: "application/x-protobuf",
          disposition: "inline"
      end
    end
  end
end
