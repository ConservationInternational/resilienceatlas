# == Schema Information
#
# Table name: static_page_bases
#
#  id                :bigint           not null, primary key
#  slug              :string           not null
#  image_credits_url :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string
#  image_credits     :string
#
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

    def self.ransackable_attributes(auth_object = nil)
      %w[id slug image_credits_url created_at updated_at title image_credits]
    end

    def self.ransackable_associations(auth_object = nil)
      %w[sections translations image_attachment image_blob]
    end
  end
end
