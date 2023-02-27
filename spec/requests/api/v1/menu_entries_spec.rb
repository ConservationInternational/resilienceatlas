require "swagger_helper"

RSpec.describe "API V1 Map Menu Entries", type: :request do
  path "/api/menu-entries" do
    get "Get list of map menu entries" do
      tags "MapMenuEntry"
      consumes "application/json"
      produces "application/json"

      let!(:map_menu_entries) { create_list :map_menu_entry, 3 }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/map_menu_entries")
        end
      end
    end
  end
end
