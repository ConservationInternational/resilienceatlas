# == Schema Information
#
# Table name: layers
#
#  id                        :bigint           not null, primary key
#  layer_group_id            :integer
#  slug                      :string           not null
#  layer_type                :string
#  zindex                    :integer
#  active                    :boolean
#  order                     :integer
#  color                     :string
#  layer_provider            :string
#  css                       :text
#  interactivity             :text
#  opacity                   :float
#  query                     :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  locate_layer              :boolean          default(FALSE)
#  icon_class                :string
#  published                 :boolean          default(TRUE)
#  zoom_max                  :integer          default(100)
#  zoom_min                  :integer          default(0)
#  dashboard_order           :integer
#  download                  :boolean          default(FALSE)
#  dataset_shortname         :string
#  dataset_source_url        :text
#  start_date                :datetime
#  end_date                  :datetime
#  spatial_resolution        :string
#  spatial_resolution_units  :string
#  temporal_resolution       :string
#  temporal_resolution_units :string
#  update_frequency          :string
#  version                   :string
#  analysis_suitable         :boolean          default(FALSE)
#  analysis_query            :text
#  layer_config              :text
#  analysis_body             :text
#  interaction_config        :text
#  timeline                  :boolean          default(FALSE)
#  timeline_steps            :date             default([]), is an Array
#  timeline_start_date       :date
#  timeline_end_date         :date
#  timeline_default_date     :date
#  timeline_period           :string
#  analysis_type             :string
#  name                      :string
#  info                      :text
#  legend                    :text
#  title                     :string
#  data_units                :string
#  processing                :string
#  description               :text
#  analysis_text_template    :text
#

require "rails_helper"

RSpec.describe Layer, type: :model do
  subject { build(:layer) }

  it { is_expected.to be_valid }

  it "should not be valid without slug" do
    subject.slug = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:slug]).to include("can't be blank")
  end

  it "should not be valid without layer_provider" do
    subject.layer_provider = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:layer_provider]).to include("can't be blank")
  end

  it "should not be valid without interaction_config" do
    subject.interaction_config = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:interaction_config]).to include("can't be blank")
  end

  it "should not be valid without name" do
    subject.name = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.name"]).to include("can't be blank")
  end

  describe "slug validation" do
    it "should require a unique slug" do
      create(:layer, slug: "test-layer")
      subject.slug = "test-layer"
      expect(subject).not_to be_valid
      expect(subject.errors[:slug]).to include("has already been taken")
    end

    it "should accept valid lowercase slugs with hyphens" do
      subject.slug = "valid-layer-name"
      expect(subject).to be_valid
    end

    it "should accept slugs with underscores" do
      subject.slug = "valid_layer_name"
      expect(subject).to be_valid
    end

    it "should accept slugs with uppercase letters" do
      subject.slug = "Valid_Layer_Name"
      expect(subject).to be_valid
    end

    it "should reject slugs with spaces" do
      subject.slug = "invalid layer"
      expect(subject).not_to be_valid
    end

    it "should reject slugs with special characters other than hyphens and underscores" do
      subject.slug = "invalid-layer!"
      expect(subject).not_to be_valid
    end
  end

  describe "numeric validations" do
    it "should reject opacity values greater than 1" do
      subject.opacity = 1.5
      expect(subject).not_to be_valid
      expect(subject.errors[:opacity]).to include("must be less than or equal to 1")
    end

    it "should reject opacity values less than 0" do
      subject.opacity = -0.1
      expect(subject).not_to be_valid
      expect(subject.errors[:opacity]).to include("must be greater than or equal to 0")
    end

    it "should accept valid opacity values" do
      subject.opacity = 0.5
      expect(subject).to be_valid
    end

    it "should reject zoom_min values greater than 24" do
      subject.zoom_min = 25
      expect(subject).not_to be_valid
      expect(subject.errors[:zoom_min]).to include("must be less than or equal to 24")
    end

    it "should reject zoom_max values greater than 24" do
      subject.zoom_max = 25
      expect(subject).not_to be_valid
      expect(subject.errors[:zoom_max]).to include("must be less than or equal to 24")
    end

    it "should reject zoom_max less than zoom_min" do
      subject.zoom_min = 10
      subject.zoom_max = 5
      expect(subject).not_to be_valid
      expect(subject.errors[:zoom_max]).to include("must be greater than or equal to zoom_min")
    end
  end

  describe "JSON validation" do
    it "should reject invalid JSON in interaction_config" do
      subject.interaction_config = "not valid json"
      expect(subject).not_to be_valid
      expect(subject.errors[:interaction_config]).to include("must be valid JSON")
    end

    it "should accept valid JSON in interaction_config" do
      subject.interaction_config = '{"output": [], "enabled": true}'
      expect(subject).to be_valid
    end

    it "should reject invalid JSON in layer_config when present" do
      subject.layer_config = "not valid json"
      expect(subject).not_to be_valid
      expect(subject.errors[:layer_config]).to include("must be valid JSON")
    end

    it "should accept valid JSON in layer_config" do
      subject.layer_config = '{"type": "raster"}'
      expect(subject).to be_valid
    end

    it "should reject invalid JSON in analysis_body when present" do
      subject.analysis_body = "not valid json"
      expect(subject).not_to be_valid
      expect(subject.errors[:analysis_body]).to include("must be valid JSON")
    end

    it "should accept valid JSON in analysis_body" do
      subject.analysis_body = '{"url": "https://example.com/cog.tif"}'
      expect(subject).to be_valid
    end
  end

  context "when analysis is enabled" do
    subject { build :layer, analysis_suitable: true }

    it "should not be valid when analysis type is histogram for cartodb provider" do
      subject.layer_provider = "cartodb"
      subject.analysis_type = "histogram"
      expect(subject).not_to be_valid
      expect(subject.errors[:analysis_type]).to include("analysis type has to be text for cartodb provider")
    end

    it "should not be valid when analysis type is categorical for cartodb provider" do
      subject.layer_provider = "cartodb"
      subject.analysis_type = "categorical"
      expect(subject).not_to be_valid
      expect(subject.errors[:analysis_type]).to include("analysis type has to be text for cartodb provider")
    end

    it "should be valid when analysis type is text for cartodb provider" do
      subject.layer_provider = "cartodb"
      subject.analysis_type = "text"
      expect(subject).to be_valid
    end

    it "should not be valid when analysis type is text for cog provider" do
      subject.layer_provider = "cog"
      subject.analysis_type = "text"
      expect(subject).not_to be_valid
      expect(subject.errors[:analysis_type]).to include("analysis type has to be histogram or categorical for cog provider")
    end

    it "should be valid when analysis type is histogram for cog provider" do
      subject.layer_provider = "cog"
      subject.analysis_type = "histogram"
      expect(subject).to be_valid
    end

    it "should be valid when analysis type is categorical for cog provider" do
      subject.layer_provider = "cog"
      subject.analysis_type = "categorical"
      expect(subject).to be_valid
    end

    it "should not be valid when analysis type is text for raster provider" do
      subject.layer_provider = "raster"
      subject.analysis_type = "text"
      expect(subject).not_to be_valid
      expect(subject.errors[:analysis_type]).to include("analysis type has to be histogram")
    end

    it "should not be valid when analysis type is categorical for raster provider" do
      subject.layer_provider = "raster"
      subject.analysis_type = "categorical"
      expect(subject).not_to be_valid
      expect(subject.errors[:analysis_type]).to include("analysis type has to be histogram")
    end

    it "should be valid when analysis type is histogram for raster provider" do
      subject.layer_provider = "raster"
      subject.analysis_type = "histogram"
      expect(subject).to be_valid
    end
  end

  context "when timeline is enabled" do
    subject { build :layer, timeline: true }

    it "should not be valid without timeline_start_date when timeline_steps are empty" do
      subject.timeline_steps = []
      subject.timeline_start_date = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:timeline_start_date]).to include("required unless Steps defined")
    end
  end

  context "when layer is a cog" do
    subject { build :layer, layer_provider: "cog" }

    it "should not be valid without layer_config" do
      subject.layer_config = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:layer_config]).to include("can't be blank")
    end
  end

  describe "#clone!" do
    let!(:layer) { create :layer }
    let(:cloned_layer) { Layer.where.not(id: layer.id).last }

    before do
      I18n.with_locale(:es) { layer.update! name: "Name ES", info: "Info ES" } # add extra translation
      layer.clone!
    end

    it "clones basic attributes" do
      expect(cloned_layer.attributes.except("id", "name", "created_at", "updated_at"))
        .to eq(layer.attributes.except("id", "name", "created_at", "updated_at"))
    end

    it "clones translations" do
      expect(cloned_layer.translations.map { |t| t.attributes.except("id", "name", "layer_id", "created_at", "updated_at") })
        .to match_array(layer.translations.map { |t| t.attributes.except("id", "name", "layer_id", "created_at", "updated_at") })
    end

    it "updates name of cloned layer" do
      expect(cloned_layer.name).to include("#{layer.name} _copy_ ")
    end
  end

  describe "layer_config" do
    context "with timeline configuration" do
      let(:layer) do
        create(:layer,
          timeline: true,
          timeline_start_date: Date.new(2020, 1, 1),
          timeline_end_date: Date.new(2023, 12, 31),
          layer_config: '{"type": "raster", "url": "https://example.com/{year}/{month}/{day}"}')
      end

      it "stores layer_config as text" do
        expect(layer.layer_config).to be_a(String)
        expect(layer.layer_config).to include("year")
        expect(layer.layer_config).to include("month")
      end

      it "preserves timeline parameters" do
        expect(layer.timeline_start_date).to eq(Date.new(2020, 1, 1))
        expect(layer.timeline_end_date).to eq(Date.new(2023, 12, 31))
      end
    end

    context "with cartodb configuration" do
      let(:layer) do
        create(:layer,
          layer_provider: "cartodb",
          layer_config: '{"type": "cartodb", "sql": "SELECT * FROM table"}')
      end

      it "stores cartodb layer_config" do
        expect(layer.layer_config).to include("cartodb")
        expect(layer.layer_config).to include("SELECT")
      end
    end

    context "with cog configuration" do
      let(:layer) do
        create(:layer,
          layer_provider: "cog",
          analysis_suitable: true,
          analysis_type: "histogram",
          layer_config: '{"type": "cog", "url": "https://example.com/data.tif"}')
      end

      it "stores cog layer_config" do
        expect(layer.layer_config).to include("cog")
        expect(layer.layer_config).to include(".tif")
      end

      it "supports histogram analysis" do
        expect(layer.analysis_suitable).to be true
        expect(layer.analysis_type).to eq("histogram")
      end
    end
  end

  describe "interaction_config" do
    let(:layer) do
      create(:layer,
        interaction_config: '{"output": [{"column": "name", "property": "Name"}]}')
    end

    it "stores interaction configuration as text" do
      expect(layer.interaction_config).to be_a(String)
      expect(layer.interaction_config).to include("output")
    end

    it "can be parsed as JSON" do
      config = JSON.parse(layer.interaction_config)
      expect(config).to have_key("output")
      expect(config["output"]).to be_an(Array)
    end
  end

  describe "associations" do
    let(:layer) { create(:layer) }
    let(:layer_group) { create(:layer_group) }
    let(:source) { create(:source) }

    it "can be associated with layer_groups" do
      layer.layer_groups << layer_group
      expect(layer.layer_groups).to include(layer_group)
    end

    it "can be associated with sources" do
      layer.sources << source
      expect(layer.sources).to include(source)
    end
  end

  describe "download functionality" do
    context "when download is enabled" do
      let(:layer) { create(:layer, download: true, dataset_shortname: "test_dataset") }

      it "allows downloads" do
        expect(layer.download).to be true
      end

      it "has dataset information" do
        expect(layer.dataset_shortname).to eq("test_dataset")
      end
    end

    context "when download is disabled" do
      let(:layer) { create(:layer, download: false) }

      it "does not allow downloads" do
        expect(layer.download).to be false
      end
    end
  end
end
