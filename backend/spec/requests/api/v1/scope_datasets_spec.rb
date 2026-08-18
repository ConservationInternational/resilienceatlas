require "rails_helper"

RSpec.describe "API V1 Scope Datasets", type: :request do
  describe "GET /api/scope-datasets/ldn-ecoregion-at-point" do
    let(:connection) { ActiveRecord::Base.connection }
    let!(:site_scope) { create(:site_scope) }

    before do
      allow(connection).to receive(:select_value).and_call_original
      allow(connection).to receive(:select_value)
        .with("SELECT to_regclass('ra_vector.ldn_dissolved_geometries') IS NOT NULL")
        .and_return(true)
      allow(connection).to receive(:select_value)
        .with("SELECT to_regclass('ra_nonspatial.ldn_ecoregion_stats') IS NOT NULL")
        .and_return(true)
    end

    it "returns ecoregion metadata and statistics for the requested methodology" do
      expect(connection).to receive(:select_one) do |sql|
        expect(sql).to include("FROM ra_vector.ldn_dissolved_geometries e")
        expect(sql).to include("LEFT JOIN ra_nonspatial.ldn_ecoregion_stats s")
        expect(sql).to include("s.methodology = 'trendsearth'")
        expect(sql).to include("ST_Covers(e.geom")

        {
          "eco_id" => 101,
          "eco_name" => "Test ecoregion",
          "biome_name" => "Test biome",
          "realm" => "Test realm",
          "total_area_km2" => 100.0,
          "baseline_degraded_sqkm" => 20.0,
          "gains_km2" => 8.0,
          "losses_km2" => 3.0,
          "delta_ldn_km2" => 5.0,
          "ldn_pct" => 5.0
        }
      end

      get "/api/scope-datasets/ldn-ecoregion-at-point",
        params: {
          lat: 1.25,
          lng: 2.5,
          methodology: "trendsearth",
          site_scope: site_scope.subdomain
        }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to match(
        "rows" => [
          hash_including(
            "eco_id" => 101,
            "eco_name" => "Test ecoregion",
            "ldn_pct" => 5.0
          )
        ]
      )
    end
  end
end
