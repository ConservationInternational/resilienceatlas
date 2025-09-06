require "swagger_helper"

RSpec.describe "API V1 Static Pages", type: :request do
  path "/api/static_pages/{slug}" do
    get "Get static page with appropriate slug" do
      tags "StaticPage"
      consumes "application/json"
      produces "application/json"
      parameter name: :slug, in: :path, type: :string, description: "Slug of static page", required: true
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let!(:static_page) { create :static_page }
      let!(:static_page_section_paragraph) do
        create :static_page_section_paragraph, section: create(:static_page_section, section_type: :paragraph, static_page: static_page)
      end
      let!(:static_page_section_item) do
        create :static_page_section_item, section: create(:static_page_section, section_type: :items, static_page: static_page)
      end
      let!(:static_page_section_reference) do
        create :static_page_section_reference, section: create(:static_page_section, section_type: :references, static_page: static_page)
      end
      let(:slug) { static_page.slug }

      it_behaves_like "with not found error"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_static_page")
        end
      end
    end
  end
end
