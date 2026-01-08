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

  def self.ransackable_attributes(auth_object = nil)
    %w[id layer_id layer_group_id active]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[layer layer_group]
  end
end
