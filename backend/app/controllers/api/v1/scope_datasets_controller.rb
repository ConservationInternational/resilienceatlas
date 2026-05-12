module Api
  module V1
    class ScopeDatasetsController < ApiController
      include SitesFilters

      skip_before_action :check_site_scope_authentication, only: [:index, :show, :intersecting_units, :geometry_bounds, :geometry_at_point]

      def index
        datasets = ScopeDataset.for_site_scope(params[:site_scope])
          .ordered
        if geometry_table_exists?
          datasets = datasets.select(
            "scope_datasets.*",
            "(SELECT COUNT(*) FROM scope_dataset_geometries WHERE scope_dataset_geometries.scope_dataset_id = scope_datasets.id) AS geom_count_cache"
          )
        end
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: datasets, each_serializer: ScopeDatasetSerializer,
          meta: {total_datasets: datasets.size}
      end

      def show
        dataset = ScopeDataset.find_by!(
          site_scope_id: params[:site_scope],
          slug: params[:slug]
        )
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: dataset, serializer: ScopeDatasetDetailSerializer
      end

      def geometry_bounds
        unless geometry_table_exists?
          render json: {error: "Geometry table not available"}, status: :not_found
          return
        end

        dataset = ScopeDataset.find_by!(
          site_scope_id: params[:site_scope],
          slug: params[:slug]
        )

        unit_id = params[:unit_id]
        unless unit_id.present?
          render json: {error: "unit_id parameter is required"}, status: :unprocessable_entity
          return
        end

        result = ActiveRecord::Base.connection.select_one(
          ActiveRecord::Base.sanitize_sql_array([<<~SQL, dataset.id, unit_id.to_s])
            SELECT
              ST_AsGeoJSON(geom, 6) AS geojson,
              ST_XMin(ST_Extent(geom) OVER ()) AS west,
              ST_YMin(ST_Extent(geom) OVER ()) AS south,
              ST_XMax(ST_Extent(geom) OVER ()) AS east,
              ST_YMax(ST_Extent(geom) OVER ()) AS north
            FROM scope_dataset_geometries
            WHERE scope_dataset_id = ? AND unit_id = ?
            LIMIT 1
          SQL
        )

        unless result && result["geojson"]
          render json: {error: "Geometry not found"}, status: :not_found
          return
        end

        expires_in 1.day, public: true, stale_while_revalidate: 1.hour
        render json: {
          bounds: [
            [result["south"].to_f, result["west"].to_f],
            [result["north"].to_f, result["east"].to_f]
          ],
          geometry: JSON.parse(result["geojson"])
        }
      end

      def geometry_at_point
        unless geometry_table_exists?
          render json: []
          return
        end

        lat = params[:lat].to_f
        lng = params[:lng].to_f

        unless params[:lat].present? && params[:lng].present? &&
            lat.between?(-90, 90) && lng.between?(-180, 180)
          render json: {error: "Valid lat and lng parameters are required"}, status: :unprocessable_entity
          return
        end

        site_scope_condition = ActiveRecord::Base.sanitize_sql_array(
          ["sd.site_scope_id = ?", params[:site_scope].to_i]
        )

        point_condition = ActiveRecord::Base.sanitize_sql_array(
          ["ST_Contains(g.geom, ST_SetSRID(ST_MakePoint(?, ?), 4326))", lng, lat]
        )

        results = ActiveRecord::Base.connection.select_all(<<~SQL)
          SELECT
            sd.slug,
            g.unit_id,
            ST_AsGeoJSON(g.geom, 6) AS geojson,
            ST_XMin(ST_Envelope(g.geom)) AS west,
            ST_YMin(ST_Envelope(g.geom)) AS south,
            ST_XMax(ST_Envelope(g.geom)) AS east,
            ST_YMax(ST_Envelope(g.geom)) AS north
          FROM scope_dataset_geometries g
          JOIN scope_datasets sd ON sd.id = g.scope_dataset_id
          WHERE #{site_scope_condition}
            AND #{point_condition}
          ORDER BY sd.display_order ASC
        SQL

        render json: results.map { |row|
          {
            slug: row["slug"],
            unit_id: row["unit_id"],
            geometry: JSON.parse(row["geojson"]),
            bounds: [
              [row["south"].to_f, row["west"].to_f],
              [row["north"].to_f, row["east"].to_f]
            ]
          }
        }
      end

      def intersecting_units
        unless geometry_table_exists?
          render json: {}
          return
        end

        if params[:iso].present?
          boundary = AdminBoundary.countries.find_by(iso_code: params[:iso])
          unless boundary
            render json: {error: "Country not found"}, status: :not_found
            return
          end
          filter_condition = ActiveRecord::Base.sanitize_sql_array(
            ["ST_Intersects(g.geom, (SELECT geom FROM admin_boundaries WHERE id = ?))", boundary.id]
          )
        elsif params[:geometry].present?
          filter_condition = ActiveRecord::Base.sanitize_sql_array(
            ["ST_Intersects(g.geom, ST_SetSRID(ST_GeomFromGeoJSON(?), 4326))", params[:geometry]]
          )
        else
          render json: {error: "Either iso or geometry parameter is required"}, status: :unprocessable_entity
          return
        end

        site_scope_condition = ActiveRecord::Base.sanitize_sql_array(
          ["sd.site_scope_id = ?", params[:site_scope].to_i]
        )

        results = ActiveRecord::Base.connection.select_all(<<~SQL)
          SELECT sd.slug, array_agg(g.unit_id ORDER BY g.unit_id) AS unit_ids
          FROM scope_dataset_geometries g
          JOIN scope_datasets sd ON sd.id = g.scope_dataset_id
          WHERE #{site_scope_condition}
            AND #{filter_condition}
          GROUP BY sd.slug
        SQL

        render json: results.rows.to_h { |slug, unit_ids| [slug, parse_pg_array(unit_ids)] }
      end

      private

      def parse_pg_array(val)
        return val if val.is_a?(Array)
        return [] if val.nil?
        val.gsub(/[{}"]/, "").split(",")
      end

      def geometry_table_exists?
        @geometry_table_exists ||= ActiveRecord::Base.connection.table_exists?("scope_dataset_geometries")
      rescue ActiveRecord::StatementInvalid
        false
      end
    end
  end
end
