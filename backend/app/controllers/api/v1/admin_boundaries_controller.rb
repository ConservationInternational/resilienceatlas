module Api
  module V1
    class AdminBoundariesController < ApiController
      include SitesFilters
      skip_before_action :set_site, only: [:index]
      skip_before_action :check_site_scope_authentication, only: [:index]

      def index
        level = params[:admin_level].present? ? params[:admin_level].to_i : 0

        boundaries = AdminBoundary
          .where(admin_level: level)
          .select(
            "id, name, iso_code, admin_level, parent_iso_code",
            "ST_AsGeoJSON(ST_Simplify(geom, 0.01)) AS geometry_json"
          )
          .order(:name)

        expires_in 24.hours, public: true
        render json: {data: boundaries.map { |b| serialize_boundary(b) }}
      end

      private

      def serialize_boundary(b)
        {
          iso_code: b.iso_code,
          name: b.name,
          admin_level: b.admin_level,
          parent_iso_code: b.parent_iso_code,
          geometry: b.geometry_json
        }
      end
    end
  end
end
