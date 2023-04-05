# == Schema Information
#
# Table name: homepages
#
#  id                  :bigint           not null, primary key
#  homepage_journey_id :bigint
#  site_scope_id       :bigint           not null
#  credits_url         :string
#  show_journeys       :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  title               :string
#  subtitle            :string
#  credits             :string
#
class Homepage < ApplicationRecord
  belongs_to :site_scope
  belongs_to :homepage_journey, optional: true, dependent: :destroy

  has_many :homepage_sections, dependent: :destroy

  has_one_attached :background_image, service: :local_public

  translates :title, :subtitle, :credits, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :title, :subtitle, :credits

  translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }
  translation_class.validates_presence_of :subtitle, if: -> { locale.to_s == I18n.default_locale.to_s }

  validates_presence_of :homepage_journey, if: -> { show_journeys }
  validates_uniqueness_of :site_scope_id

  validates :show_journeys, inclusion: {in: [true, false]}
  validates :background_image, presence: true, content_type: /\Aimage\/.*\z/
  validates :credits_url, url: true

  accepts_nested_attributes_for :homepage_journey, allow_destroy: true
  accepts_nested_attributes_for :homepage_sections, allow_destroy: true
end
