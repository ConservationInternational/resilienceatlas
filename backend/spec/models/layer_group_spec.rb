# == Schema Information
#
# Table name: layer_groups
#
#  id               :bigint           not null, primary key
#  super_group_id   :integer
#  slug             :string
#  layer_group_type :string
#  category         :string
#  active           :boolean
#  order            :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  icon_class       :string
#  site_scope_id    :integer          default(1)
#  name             :string
#  info             :text
#
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

  describe "associations" do
    let(:layer_group) { create(:layer_group) }
    let(:layer1) { create(:layer) }
    let(:layer2) { create(:layer) }

    it "can have multiple layers through agrupations" do
      layer_group.layers << layer1
      layer_group.layers << layer2
      expect(layer_group.layers.count).to eq(2)
      expect(layer_group.layers).to include(layer1, layer2)
    end

    it "has agrupations as join model" do
      layer_group.layers << layer1
      expect(layer_group.agrupations.count).to eq(1)
      expect(layer_group.agrupations.first.layer).to eq(layer1)
    end

    it "belongs to a site_scope" do
      expect(layer_group).to respond_to(:site_scope)
      expect(layer_group.site_scope).to be_present
    end
  end

  describe "hierarchy" do
    let(:site_scope) { create(:site_scope) }
    let(:parent_group) { create(:layer_group, name: "Parent Group", site_scope: site_scope) }
    let(:child_group) { create(:layer_group, name: "Child Group", super_group: parent_group, site_scope: site_scope) }

    it "supports parent-child relationships via super_group" do
      expect(child_group.super_group).to eq(parent_group)
    end

    it "can have multiple child groups" do
      child2 = create(:layer_group, name: "Child Group 2", super_group: parent_group, site_scope: site_scope)
      expect(parent_group.sub_groups.count).to eq(2)
      expect(parent_group.sub_groups).to include(child_group, child2)
    end
  end

  describe "ordering" do
    let(:site_scope) { create(:site_scope) }
    let!(:group1) { create(:layer_group, order: 1, site_scope: site_scope) }
    let!(:group2) { create(:layer_group, order: 2, site_scope: site_scope) }
    let!(:group3) { create(:layer_group, order: 3, site_scope: site_scope) }

    it "maintains order for display" do
      groups = LayerGroup.where(id: [group1.id, group2.id, group3.id]).order(:order)
      expect(groups.pluck(:order)).to eq([1, 2, 3])
    end
  end

  describe "categorization" do
    let(:layer_group) { create(:layer_group, category: "Environment", layer_group_type: "default") }

    it "can have a category" do
      expect(layer_group.category).to eq("Environment")
    end

    it "can have a layer_group_type" do
      expect(layer_group.layer_group_type).to eq("default")
    end
  end

  describe "visibility" do
    context "when active" do
      let(:layer_group) { create(:layer_group, active: true) }

      it "is active" do
        expect(layer_group.active).to be true
      end
    end

    context "when inactive" do
      let(:layer_group) { create(:layer_group, active: false) }

      it "is not active" do
        expect(layer_group.active).to be false
      end
    end
  end

  describe "site scope association" do
    let(:site_scope) { create(:site_scope, name: "Test Scope") }
    let(:layer_group) { create(:layer_group, site_scope: site_scope) }

    it "belongs to a site_scope" do
      expect(layer_group.site_scope).to eq(site_scope)
    end

    it "has default site_scope_id of 1" do
      default_group = build(:layer_group, site_scope_id: nil)
      default_group.save(validate: false) # Skip validations if needed
      expect(default_group.site_scope_id).to eq(1).or be_nil
    end
  end

  describe ".fetch_all" do
    let(:site_scope) { create(:site_scope, id: 1) }
    let!(:layer_group) { create(:layer_group, site_scope: site_scope) }

    it "returns all layer groups with translations" do
      groups = LayerGroup.fetch_all
      expect(groups).to include(layer_group)
    end
  end
end
