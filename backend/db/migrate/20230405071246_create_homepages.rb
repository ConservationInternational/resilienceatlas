class CreateHomepages < ActiveRecord::Migration[7.0]
  def change
    create_table :homepages do |t|
      t.belongs_to :homepage_journey, foreign_key: {on_delete: :nullify}
      t.belongs_to :site_scope, foreign_key: {on_delete: :cascade}, null: false, index: {unique: true}
      t.string :credits_url
      t.boolean :show_journeys, null: false, default: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        Homepage.create_translation_table! title: :string, subtitle: :string, credits: :string
      end

      dir.down do
        Homepage.drop_translation_table!
      end
    end
  end
end
