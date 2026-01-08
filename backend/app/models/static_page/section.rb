# == Schema Information
#
# Table name: static_page_sections
#
#  id                 :bigint           not null, primary key
#  static_page_id     :bigint           not null
#  position           :integer          not null
#  slug               :string
#  section_type       :string           not null
#  title_size         :integer          default(2)
#  show_at_navigation :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  title              :string
#
module StaticPage
  class Section < ApplicationRecord
    belongs_to :static_page, class_name: "StaticPage::Base", inverse_of: :sections
    has_one :section_paragraph, class_name: "StaticPage::SectionParagraph", dependent: :destroy
    has_many :section_items, class_name: "StaticPage::SectionItem", dependent: :destroy
    has_many :section_references, class_name: "StaticPage::SectionReference", dependent: :destroy

    enum :section_type, {paragraph: "paragraph", items: "items", references: "references"}, default: :paragraph, prefix: true

    translates :title, touch: true, fallbacks_for_empty_translations: true
    active_admin_translates :title

    translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }

    validates_presence_of :position, :section_type
    validates :position, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates :show_at_navigation, inclusion: {in: [true, false]}

    accepts_nested_attributes_for :section_paragraph, allow_destroy: true
    accepts_nested_attributes_for :section_items, allow_destroy: true
    accepts_nested_attributes_for :section_references, allow_destroy: true
  end
end
