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

class MapMenuEntry < ApplicationRecord
  has_ancestry orphan_strategy: :destroy

  translates :label, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :label

  validates_presence_of :position
  translation_class.validates_presence_of :label, if: -> { locale.to_s == I18n.default_locale.to_s }
end
