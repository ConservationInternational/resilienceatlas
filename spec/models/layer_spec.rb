# == Schema Information
#
# Table name: layers
#
#  id                        :integer          not null, primary key
#  layer_group_id            :integer
#  name                      :string           not null
#  slug                      :string           not null
#  layer_type                :string
#  zindex                    :integer
#  active                    :boolean
#  order                     :integer
#  color                     :string
#  info                      :text
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
#  legend                    :text
#  zoom_max                  :integer          default(100)
#  zoom_min                  :integer          default(0)
#  dashboard_order           :integer
#  download                  :boolean          default(FALSE)
#  dataset_shortname         :string
#  dataset_source_url        :text
#  source_id                 :integer
#  title                     :string
#  start_date                :datetime
#  end_date                  :datetime
#  spatial_resolution        :string
#  spatial_resolution_units  :string
#  temporal_resolution       :string
#  temporal_resolution_units :string
#  data_units                :string
#  update_frequency          :string
#  version                   :string
#  processing                :string
#  description               :text
#

require 'rails_helper'

RSpec.describe Layer, type: :model do
  before :each do
    @source = create(:with_source)
    @layer = @source.layers.first
  end

  it 'Layer is valid' do
    expect(@layer).to                    be_valid
    expect(@layer.source.source_type).to eq('Info')
  end

  it 'Count layers' do
    expect(Layer.count).to eq(1)
  end
end
