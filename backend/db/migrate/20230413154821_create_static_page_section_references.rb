class CreateStaticPageSectionReferences < ActiveRecord::Migration[7.0]
  def change
    create_table :static_page_section_references do |t|
      t.belongs_to :section, null: false, foreign_key: {on_delete: :cascade, to_table: :static_page_sections}
      t.string :slug
      t.integer :position, null: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        StaticPage::SectionReference.create_translation_table! text: :text
      end

      dir.down do
        StaticPage::SectionReference.drop_translation_table!
      end
    end
  end
end
