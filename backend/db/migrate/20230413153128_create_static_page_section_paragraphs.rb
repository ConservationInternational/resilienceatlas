class CreateStaticPageSectionParagraphs < ActiveRecord::Migration[7.0]
  def change
    create_table :static_page_section_paragraphs do |t|
      t.belongs_to :section, null: false, foreign_key: {on_delete: :cascade, to_table: :static_page_sections}
      t.string :image_position, null: false
      t.string :image_credits_url

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        StaticPage::SectionParagraph.create_translation_table! text: :text, image_credits: :string
      end

      dir.down do
        StaticPage::SectionParagraph.drop_translation_table!
      end
    end
  end
end
