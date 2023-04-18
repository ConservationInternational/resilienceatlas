module StaticPage
  class SectionReference < ApplicationRecord
    belongs_to :section, class_name: "StaticPage::Section", inverse_of: :section_references

    has_rich_text :text

    translates :text, touch: true, fallbacks_for_empty_translations: true
    active_admin_translates :text

    validates_presence_of :position
    validates :position, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  end
end
