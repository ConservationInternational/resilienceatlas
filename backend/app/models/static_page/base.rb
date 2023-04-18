module StaticPage
  class Base < ApplicationRecord
    has_many :sections, class_name: "StaticPage::Section", foreign_key: "static_page_id", inverse_of: :static_page, dependent: :destroy

    has_one_attached :image, service: :local_public

    translates :title, :image_credits, touch: true, fallbacks_for_empty_translations: true
    active_admin_translates :title, :image_credits

    translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }

    validates_presence_of :slug
    validates_uniqueness_of :slug
    validates :image_credits_url, url: true
    validates :image, presence: true, content_type: /\Aimage\/.*\z/

    accepts_nested_attributes_for :sections, allow_destroy: true
  end
end
