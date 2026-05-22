class CreateHomepageJourneys < ActiveRecord::Migration[7.0]
  def change
    create_table :homepage_journeys do |t|
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        HomepageJourney.create_translation_table! title: :string
      end

      dir.down do
        HomepageJourney.drop_translation_table!
      end
    end
  end
end
