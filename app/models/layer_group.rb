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
#  icon_class       :string
#

class LayerGroup < ActiveRecord::Base
  has_many :agrupations
  has_many :layers, through: :agrupations
  belongs_to :super_group, class_name: 'LayerGroup'
  has_many :sub_groups, class_name: 'LayerGroup', foreign_key: :super_group_id, dependent: :nullify
  accepts_nested_attributes_for :agrupations, :allow_destroy => true
end
