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

class MapMenuEntry < ApplicationRecord
  has_ancestry orphan_strategy: :destroy
  validates_presence_of :label, :position
end
