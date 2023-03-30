class CreateJourneys < ActiveRecord::Migration[7.0]
  def change
    create_table :journeys do |t|
      t.string :credits
      t.string :credits_url

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        Journey.create_translation_table! title: :string, subtitle: :string, theme: :text
      end

      dir.down do
        Journey.drop_translation_table!
      end
    end
  end
end
