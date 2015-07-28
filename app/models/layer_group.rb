# == Schema Information
#
# Table name: layer_groups
#
#  id               :integer          not null, primary key
#  name             :string
#  super_group_id   :integer
#  slug             :string
#  layer_group_type :string
#  category         :string
#  active           :boolean
#  order            :integer
#  info             :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class LayerGroup < ActiveRecord::Base
  has_many :layers
  belongs_to :super_group, class_name: 'LayerGroup'
  has_many :sub_groups, class_name: 'LayerGroup', foreign_key: :super_group_id
end
