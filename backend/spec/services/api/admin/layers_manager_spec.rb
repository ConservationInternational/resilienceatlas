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

      it "links to an explicit layer group without creating 'New uploads'" do
        explicit_group = create(:layer_group, site_scope: site_scope, name: "Ecoregions", slug: "ecoregions")
        manager = described_class.new(layer, site_scope.id, layer_group_id: explicit_group.id)

        expect {
          manager.link_layer_group
        }.to change { Agrupation.count }.by(1)
          .and change { LayerGroup.where(name: "New uploads").count }.by(0)

        expect(Agrupation.last.layer_group).to eq(explicit_group)
      end

      it "does not link a layer group from another site scope" do
        other_group = create(:layer_group)
        manager = described_class.new(layer, site_scope.id, layer_group_id: other_group.id)

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

    context "when only a valid layer_group_id is provided" do
      let(:layer_group) { create(:layer_group, site_scope: site_scope) }
      let(:manager) { described_class.new(layer, nil, layer_group_id: layer_group.id) }

      it "links the layer using the existing layer group's site scope" do
        expect {
          manager.link_layer_group
        }.to change { Agrupation.count }.by(1)

        expect(Agrupation.last.layer_group).to eq(layer_group)
      end
    end
  end
end
