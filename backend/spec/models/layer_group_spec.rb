require "rails_helper"

RSpec.describe LayerGroup, type: :model do
  subject { build(:layer_group) }

  it { is_expected.to be_valid }

  describe "#clone!" do
    let!(:layer_group) { create :layer_group, layers: [create(:layer)] }
    let(:cloned_layer_group) { LayerGroup.where.not(id: layer_group.id).last }

    before do
      I18n.with_locale(:es) { layer_group.update! name: "Name ES", info: "Info ES" } # add extra translation
      layer_group.clone!
    end

    it "clones basic attributes" do
      expect(cloned_layer_group.attributes.except("id", "name", "created_at", "updated_at"))
        .to eq(layer_group.attributes.except("id", "name", "created_at", "updated_at"))
    end

    it "clones translations" do
      expect(cloned_layer_group.translations.map { |t| t.attributes.except("id", "name", "layer_group_id", "created_at", "updated_at") })
        .to match_array(layer_group.translations.map { |t| t.attributes.except("id", "name", "layer_group_id", "created_at", "updated_at") })
    end

    it "clones agrupations" do
      expect(cloned_layer_group.agrupations.map { |a| a.attributes.except("id", "layer_group_id") })
        .to match_array(layer_group.agrupations.map { |a| a.attributes.except("id", "layer_group_id") })
    end

    it "updates name of cloned layer group" do
      expect(cloned_layer_group.name).to include("#{layer_group.name} _copy_ ")
    end
  end
end
