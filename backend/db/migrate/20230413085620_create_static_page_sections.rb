class CreateStaticPageSections < ActiveRecord::Migration[7.0]
  def change
    create_table :static_page_sections do |t|
      t.belongs_to :static_page, null: false, foreign_key: {on_delete: :cascade, to_table: :static_page_bases}
      t.integer :position, null: false
      t.string :slug
      t.string :section_type, null: false
      t.integer :title_size, default: 2
      t.boolean :show_at_navigation, null: false, default: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        StaticPage::Section.create_translation_table! title: :string
      end

      dir.down do
        StaticPage::Section.drop_translation_table!
      end
    end
  end
end
