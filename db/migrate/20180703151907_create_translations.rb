class CreateTranslations < ActiveRecord::Migration
  def change
    reversible do |dir|
      dir.up do
        Layer.create_translation_table!({ name: :string, info: :text,
                                           legend: :text, title: :string,
                                           data_units: :string,
                                           processing: :string,
                                           description: :text },
                                         { migrate_data: true,
                                           remove_source_columns: true })

        LayerGroup.create_translation_table!({ name: :string, info: :text },
                                               { migrate_data: true,
                                                 remove_source_columns: true })
      end

      dir.down do

        Layer.drop_translation_table! migrate_data: true
        LayerGroup.drop_translation_table! migrate_data: true
      end
    end
  end
end
