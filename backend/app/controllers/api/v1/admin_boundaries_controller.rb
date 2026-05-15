module Api
  module V1
    class AdminBoundariesController < ApiController
      include SitesFilters

      skip_before_action :set_site, only: [:index, :show]
      skip_before_action :check_site_scope_authentication, only: [:index, :show]

      def index
        level = params[:admin_level].present? ? params[:admin_level].to_i : 0
        include_geometry = params[:geometry] != "false"

        select_cols = ["id, name, iso_code, admin_level, parent_iso_code"]
        select_cols << "ST_AsGeoJSON(ST_Simplify(geom, 0.01)) AS geometry_json" if include_geometry

        boundaries = AdminBoundary
          .where(admin_level: level)
          .select(*select_cols)
          .order(:name)

        expires_in 24.hours, public: true
        render json: {data: boundaries.map { |b| serialize_boundary(b, include_geometry) }}
      end

      def show
        boundary = AdminBoundary
          .where(iso_code: params[:iso_code])
          .select(
            "id, name, iso_code, admin_level, parent_iso_code",
            "ST_AsGeoJSON(ST_Simplify(geom, 0.01)) AS geometry_json"
          )
          .first

        return head :not_found unless boundary

        expires_in 24.hours, public: true
        render json: {data: serialize_boundary(boundary, true)}
      end

      private

      def serialize_boundary(b, include_geometry = true)
        result = {
          iso_code: b.iso_code,
          name: b.name,
          admin_level: b.admin_level,
          parent_iso_code: b.parent_iso_code
        }
        result[:geometry] = b.geometry_json if include_geometry
        result
      end
    end
  end
end
