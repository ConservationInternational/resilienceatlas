# == Schema Information
#
# Table name: agrupations
#
#  id             :bigint           not null, primary key
#  layer_id       :bigint
#  layer_group_id :bigint
#  active         :boolean          default(FALSE)
#

class Agrupation < ApplicationRecord
  belongs_to :layer
  belongs_to :layer_group
  validates_uniqueness_of :layer, scope: :layer_group
end
