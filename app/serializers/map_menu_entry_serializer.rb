# == Schema Information
#
# Table name: map_menu_entries
#
#  id         :integer          not null, primary key
#  label      :string
#  link       :string
#  position   :integer
#  created_at :datetime
#  updated_at :datetime
#  ancestry   :string
#

class MapMenuEntrySerializer < ActiveModel::Serializer
  attributes :id, :label, :link, :position, :ancestry
end
