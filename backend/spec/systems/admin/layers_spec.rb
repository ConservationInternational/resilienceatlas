require "system_helper"

RSpec.describe "Admin: Layers", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:layers) { create_list :layer, 3 }

    before { visit admin_layers_path }

    it "shows all resources" do
      Layer.all.each do |layer|
        expect(page).to have_text(layer.name)
        expect(page).to have_text(layer.slug)
      end
    end
  end

  describe "#show" do
    context "with cartodb layer provider" do
      let!(:layer) { create :layer, layer_provider: :cartodb, analysis_suitable: true }

      before do
        visit admin_layers_path
        find("a[href='/admin/layers/#{layer.id}']", text: "View").click
      end

      it "shows layer detail" do
        expect(page).to have_text(layer.id)
        expect(page).to have_text(layer.slug)
        expect(page).to have_text(layer.name)
        expect(page).to have_text(layer.description)
        expect(page).to have_text(layer.processing)
        expect(page).to have_text(layer.data_units)
        expect(page).to have_text(layer.legend)
        expect(page).to have_text(layer.layer_provider)
        expect(page).to have_text(layer.query)
        expect(page).to have_text(layer.css)
        expect(page).to have_text(layer.opacity.to_s)
        expect(page).to have_text(layer.zindex.to_s)
        expect(page).to have_text(layer.order.to_s)
        expect(page).to have_text(layer.zoom_max.to_s)
        expect(page).to have_text(layer.zoom_min.to_s)
        expect(page).to have_text(layer.interaction_config)
        expect(page).to have_text(layer.analysis_query)
        expect(page).to have_text(layer.analysis_body)
        expect(page).to have_text(layer.dashboard_order.to_s)
      end
    end

    context "with cog layer provider" do
      let!(:layer) { create :layer, layer_provider: :cog, analysis_suitable: false }

      before do
        visit admin_layers_path
        find("a[href='/admin/layers/#{layer.id}']", text: "View").click
      end

      it "shows layer detail" do
        expect(page).to have_text(layer.id)
        expect(page).to have_text(layer.slug)
        expect(page).to have_text(layer.name)
        expect(page).to have_text(layer.description)
        expect(page).to have_text(layer.processing)
        expect(page).to have_text(layer.data_units)
        expect(page).to have_text(layer.legend)
        expect(page).to have_text(layer.layer_provider)
        expect(page).to have_text(layer.layer_config)
        expect(page).to have_text(layer.interaction_config)
        expect(page).to have_text(layer.dashboard_order.to_s)
      end
    end
  end

  describe "#create" do
    let(:new_layer) { Layer.last }

    before do
      visit admin_layers_path
      click_on "New Layer"
    end

    it "allows to create new layer for cartodb layer provider" do
      fill_in "layer[slug]", with: "new-layer"
      fill_in "layer[translations_attributes][0][name]", with: "New name"
      fill_in "layer[translations_attributes][0][description]", with: "New description"
      fill_in "layer[translations_attributes][0][processing]", with: "New processing"
      fill_in "layer[translations_attributes][0][data_units]", with: "New data_units"
      fill_in "layer[translations_attributes][0][legend]", with: "New legend"
      select "cartodb", from: "layer[layer_provider]"
      fill_in "layer[query]", with: "New query"
      fill_in "layer[css]", with: "New css"
      fill_in "layer[opacity]", with: "30.0"
      fill_in "layer[zindex]", with: "10000"
      fill_in "layer[order]", with: "2"
      fill_in "layer[zoom_max]", with: "1000"
      fill_in "layer[zoom_min]", with: "200"
      fill_in "layer[interaction_config]", with: "New interaction_config"
      check "layer[analysis_suitable]"
      fill_in "layer[analysis_query]", with: "New analysis_query"
      fill_in "layer[analysis_body]", with: "New analysis_body"
      check "layer[timeline]"
      fill_in "layer[timeline_overlap]", with: "New timeline_overlap"
      fill_in "layer[timeline_steps]", with: "2000-01-01,2000-01-02,2000-01-03"
      fill_in "layer[timeline_start_date]", with: "2000-01-01"
      fill_in "layer[timeline_end_date]", with: "2000-01-03"
      fill_in "layer[timeline_default_date]", with: "2000-01-01"
      select "daily", from: "layer[timeline_period]"
      fill_in "layer[timeline_format]", with: "%Y-%m-%d"
      fill_in "layer[dashboard_order]", with: "80"

      click_on "Create Layer"

      expect(page).to have_current_path(admin_layer_path(new_layer))
      expect(page).to have_text("Layer was successfully created.")
      expect(page).to have_text("new-layer")
      expect(page).to have_text("New name")
      expect(page).to have_text("New description")
      expect(page).to have_text("New processing")
      expect(page).to have_text("New data_units")
      expect(page).to have_text("New legend")
      expect(page).to have_text("cartodb")
      expect(page).to have_text("New query")
      expect(page).to have_text("New css")
      expect(page).to have_text("30.0")
      expect(page).to have_text("10000")
      expect(page).to have_text("2")
      expect(page).to have_text("1000")
      expect(page).to have_text("200")
      expect(page).to have_text("New interaction_config")
      expect(page).to have_text("New analysis_query")
      expect(page).to have_text("New analysis_body")
      expect(page).to have_text("New timeline_overlap")
      expect(page).to have_text("2000-01-01")
      expect(page).to have_text("2000-01-02")
      expect(page).to have_text("2000-01-03")
      expect(page).to have_text("daily")
      expect(page).to have_text("%Y-%m-%d")
      expect(page).to have_text("80")
    end

    it "allows to create new layer for cog layer provider" do
      fill_in "layer[slug]", with: "new-layer"
      fill_in "layer[translations_attributes][0][name]", with: "New name"
      fill_in "layer[translations_attributes][0][description]", with: "New description"
      fill_in "layer[translations_attributes][0][processing]", with: "New processing"
      fill_in "layer[translations_attributes][0][data_units]", with: "New data_units"
      fill_in "layer[translations_attributes][0][legend]", with: "New legend"
      select "cog", from: "layer[layer_provider]"
      fill_in "layer[layer_config]", with: "New layer_config"
      fill_in "layer[interaction_config]", with: "New interaction_config"
      fill_in "layer[dashboard_order]", with: "80"

      click_on "Create Layer"

      expect(page).to have_current_path(admin_layer_path(new_layer))
      expect(page).to have_text("Layer was successfully created.")
      expect(page).to have_text("new-layer")
      expect(page).to have_text("New name")
      expect(page).to have_text("New description")
      expect(page).to have_text("New processing")
      expect(page).to have_text("New data_units")
      expect(page).to have_text("New legend")
      expect(page).to have_text("cog")
      expect(page).to have_text("New layer_config")
      expect(page).to have_text("New interaction_config")
      expect(page).to have_text("80")
    end

    it "shows error when validation fails" do
      select "cog", from: "layer[layer_provider]"
      fill_in "layer[layer_config]", with: ""

      click_on "Create Layer"

      expect(page).to have_current_path(admin_layers_path)
      expect(page).to have_text("can't be blank")
    end

    it "shows errors when timeline steps are invalid" do
      check "layer[timeline]"
      fill_in "layer[timeline_steps]", with: "WRONG DATE"

      click_on "Create Layer"

      expect(page).to have_current_path(admin_layers_path)
      expect(page).to have_text("Invalid date format")
    end
  end

  describe "#update" do
    let!(:layer) { create :layer }

    before do
      visit admin_layers_path
      find("a[href='/admin/layers/#{layer.id}/edit']").click
    end

    it "allows to update existing layer" do
      fill_in "layer[translations_attributes][0][name]", with: "Update name"

      click_on "Update Layer"

      expect(page).to have_current_path(admin_layer_path(layer))
      expect(page).to have_text("Layer was successfully updated.")
      expect(page).to have_text("Update name")
    end
  end

  describe "#delete" do
    let!(:layer) { create :layer, name: "Custom name" }

    before do
      visit admin_layers_path
    end

    it "deletes existing layer" do
      expect(page).to have_text(layer.name)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/layers/#{layer.id}']").click
      end

      expect(page).not_to have_text(layer.name)
    end
  end

  describe "#publish" do
    let!(:layer) { create :layer, published: false }

    before do
      visit admin_layer_path(layer)
    end

    it "allows to change layer to published" do
      click_on "Publish Layer"

      expect(page).to have_text("Layer was published!")
      expect(layer.reload).to be_published
    end
  end

  describe "#unpublish" do
    let!(:layer) { create :layer, published: true }

    before do
      visit admin_layer_path(layer)
    end

    it "allows to change layer to published" do
      click_on "Unpublish Layer"

      expect(page).to have_text("Layer was marked as not published!")
      expect(layer.reload).not_to be_published
    end
  end
end
