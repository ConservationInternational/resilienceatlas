class CreateJourneySteps < ActiveRecord::Migration[7.0]
  def change
    create_table :journey_steps do |t|
      t.string :step_type, null: false
      t.string :credits
      t.string :credits_url
      t.string :map_theme
      t.string :mask_sql
      t.string :map_url
      t.string :btn_url
      t.string :background_color
      t.integer :chapter_number
      t.integer :position, null: false, default: 1
      t.belongs_to :journey, null: false, foreign_key: {on_delete: :cascade}

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        JourneyStep.create_translation_table! title: :string, subtitle: :string, theme: :string, content: :text
      end

      dir.down do
        JourneyStep.drop_translation_table!
      end
    end
  end
end
