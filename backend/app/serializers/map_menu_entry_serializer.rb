# == Schema Information
#
# Table name: map_menu_entries
#
#  id         :bigint           not null, primary key
#  label      :string
#  link       :string
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ancestry   :string
#

class MapMenuEntrySerializer < ActiveModel::Serializer
  attributes :id, :label, :link, :position, :ancestry
end
