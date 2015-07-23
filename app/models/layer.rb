# == Schema Information
#
# Table name: layers
#
#  id            :integer          not null, primary key
#  group_id      :integer
#  name          :string           not null
#  slug          :string           not null
#  layer_type    :string
#  zindex        :integer
#  active        :boolean
#  order         :integer
#  color         :string
#  info          :text
#  interactivity :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  opacity       :float
#  query         :text
#  css           :text
#

class Layer < ActiveRecord::Base
  belongs_to :layer_group
  accepts_nested_attributes_for :layer_group
end
