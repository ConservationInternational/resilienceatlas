class CreateHomepages < ActiveRecord::Migration[7.0]
  def change
    create_table :homepages do |t|
      t.string :credits_url
      t.integer :position, null: false, default: 1
      t.boolean :show_journeys, null: false, default: false
      t.integer :journeys_position, null: false, default: 0

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        Homepage.create_translation_table! title: :string, subtitle: :string, credits: :string, journeys_title: :string
      end

      dir.down do
        Homepage.drop_translation_table!
      end
    end
  end
end
