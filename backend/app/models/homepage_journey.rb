# == Schema Information
#
# Table name: homepage_journeys
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  title      :string
#
class HomepageJourney < ApplicationRecord
  has_one :homepage, dependent: :nullify

  translates :title, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :title

  translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }

  validates :position, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
end
