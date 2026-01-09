require "rails_helper"

RSpec.describe Api::Admin::LayersManager do
  let(:site_scope) { create(:site_scope) }
  let(:layer) { create(:layer) }
  let(:manager) { described_class.new(layer, site_scope.id) }

  describe "#link_layer_group" do
    context "when layer and site_scope_id are present" do
      it "creates or finds a layer group named 'New uploads'" do
        expect {
          manager.link_layer_group
        }.to change { LayerGroup.count }.by(1)

        layer_group = LayerGroup.last
        expect(layer_group.name).to eq("New uploads")
        expect(layer_group.site_scope).to eq(site_scope)
      end

      it "creates an agrupation linking the layer to the layer group" do
        expect {
          manager.link_layer_group
        }.to change { Agrupation.count }.by(1)

        agrupation = Agrupation.last
        expect(agrupation.layer).to eq(layer)
        expect(agrupation.layer_group.name).to eq("New uploads")
      end

      it "reuses existing 'New uploads' layer group if it exists" do
        existing_layer_group = site_scope.layer_groups.create!(name: "New uploads")

        expect {
          manager.link_layer_group
        }.not_to change { LayerGroup.count }

        agrupation = Agrupation.last
        expect(agrupation.layer_group).to eq(existing_layer_group)
      end

      it "does not create duplicate agrupations" do
        manager.link_layer_group

        expect {
          manager.link_layer_group
        }.not_to change { Agrupation.count }
      end
    end

    context "when layer is blank" do
      let(:manager) { described_class.new(nil, site_scope.id) }

      it "does not create any records" do
        expect {
          manager.link_layer_group
        }.not_to change { LayerGroup.count }
      end
    end

    context "when site_scope_id is blank" do
      let(:manager) { described_class.new(layer, nil) }

      it "does not create any records" do
        expect {
          manager.link_layer_group
        }.not_to change { LayerGroup.count }
      end
    end

    context "when site_scope does not exist" do
      let(:manager) { described_class.new(layer, 999999) }

      it "does not create any records" do
        expect {
          manager.link_layer_group
        }.not_to change { LayerGroup.count }
      end
    end
  end
end
