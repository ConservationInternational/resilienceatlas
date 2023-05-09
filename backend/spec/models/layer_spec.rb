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
#  timeline_format           :string           default("%m/%d/%Y")
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
    expect(subject).to have(1).errors_on(:slug)
  end

  it "should not be valid without layer_provider" do
    subject.layer_provider = nil
    expect(subject).to have(1).errors_on(:layer_provider)
  end

  it "should not be valid without interaction_config" do
    subject.interaction_config = nil
    expect(subject).to have(1).errors_on(:interaction_config)
  end

  it "should not be valid without name" do
    subject.name = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.name"]).to include("can't be blank")
  end

  context "when analysis is enabled" do
    subject { build :layer, analysis_suitable: true }

    it "should not be valid when analysis type is not text for cartodb provider" do
      subject.layer_provider = "cartodb"
      subject.analysis_type = "histogram"
      expect(subject).to have(1).errors_on(:analysis_type)
    end

    it "should not be valid when analysis type is not histogram for cog provider" do
      subject.layer_provider = "cog"
      subject.analysis_type = "text"
      expect(subject).to have(1).errors_on(:analysis_type)
    end
  end

  context "when timeline is enabled" do
    subject { build :layer, timeline: true }

    it "should not be valid without timeline_start_date when timeline_steps are empty" do
      subject.timeline_steps = []
      subject.timeline_start_date = nil
      expect(subject).to have(1).errors_on(:timeline_start_date)
    end

    it "should not be valid without timeline_format" do
      subject.timeline_format = nil
      expect(subject).to have(1).errors_on(:timeline_format)
    end
  end

  context "when layer is a cog" do
    subject { build :layer, layer_provider: "cog" }

    it "should not be valid without layer_config" do
      subject.layer_config = nil
      expect(subject).to have(1).errors_on(:layer_config)
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
end
