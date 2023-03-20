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
#  name                      :string
#  info                      :text
#  legend                    :text
#  title                     :string
#  data_units                :string
#  processing                :string
#  description               :text
#

require "rails_helper"

RSpec.describe Layer, type: :model do
  let(:source) { create :source }
  let!(:layer) { create :layer, sources: [source] }

  it "Layer is valid" do
    expect(layer).to be_valid
    expect(layer.sources.first.source_type).to eq(source.source_type)
  end

  it "Count layers" do
    expect(Layer.count).to eq(1)
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
