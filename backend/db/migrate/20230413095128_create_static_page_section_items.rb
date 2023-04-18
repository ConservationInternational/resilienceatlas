class CreateStaticPageSectionItems < ActiveRecord::Migration[7.0]
  def change
    create_table :static_page_section_items do |t|
      t.belongs_to :section, null: false, foreign_key: {on_delete: :cascade, to_table: :static_page_sections}
      t.integer :position, null: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        StaticPage::SectionItem.create_translation_table! title: :string, description: :text
      end

      dir.down do
        StaticPage::SectionItem.drop_translation_table!
      end
    end
  end
end
