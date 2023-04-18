module StaticPage
  class SectionParagraph < ApplicationRecord
    belongs_to :section, class_name: "StaticPage::Section", inverse_of: :section_paragraph

    has_one_attached :image, service: :local_public

    has_rich_text :text

    enum :image_position, {left: "left", right: "right"}, default: :right, prefix: true

    translates :text, :image_credits, touch: true, fallbacks_for_empty_translations: true
    active_admin_translates :text, :image_credits

    validates :image_credits_url, url: true
    validates :image, content_type: /\Aimage\/.*\z/
  end
end
