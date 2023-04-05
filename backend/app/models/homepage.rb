class Homepage < ApplicationRecord
  has_one_attached :background_image, service: :local_public

  translates :title, :subtitle, :credits, :journeys_title, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :title, :subtitle, :credits, :journeys_title

  translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }
  translation_class.validates_presence_of :subtitle, if: -> { locale.to_s == I18n.default_locale.to_s }
  translation_class.validates_presence_of :journeys_title, if: -> {
    globalized_model.show_journeys && locale.to_s == I18n.default_locale.to_s
  }

  validates_presence_of :journeys_position, if: -> { show_journeys }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :journeys_position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :show_journeys, inclusion: { in: [true, false] }
  validates :background_image, presence: true, content_type: /\Aimage\/.*\z/
  validates :credits_url, url: true
end
