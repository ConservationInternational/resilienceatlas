# == Schema Information
#
# Table name: static_page_section_items
#
#  id          :bigint           not null, primary key
#  section_id  :bigint           not null
#  position    :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  title       :string
#  description :text
#
module StaticPage
  class SectionItem < ApplicationRecord
    belongs_to :section, class_name: "StaticPage::Section", inverse_of: :section_items

    has_one_attached :image, service: :local_public

    has_rich_text :description

    translates :title, :description, touch: true, fallbacks_for_empty_translations: true
    active_admin_translates :title, :description

    translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }

    validates_presence_of :position
    validates :position, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates :image, content_type: /\Aimage\/.*\z/
  end
end
