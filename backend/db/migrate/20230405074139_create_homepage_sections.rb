class CreateHomepageSections < ActiveRecord::Migration[7.0]
  def change
    create_table :homepage_sections do |t|
      t.belongs_to :homepage, null: false, foreign_key: {on_delete: :cascade}
      t.string :button_url
      t.string :image_position
      t.string :image_credits_url
      t.string :background_color
      t.integer :position, null: false, default: 1

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        HomepageSection.create_translation_table! title: :string, subtitle: :string, button_text: :string, image_credits: :string
      end

      dir.down do
        HomepageSection.drop_translation_table!
      end
    end
  end
end
