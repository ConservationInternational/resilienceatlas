class CreateTranslations < ActiveRecord::Migration[6.0]
  def change
    reversible do |dir|
      dir.up do
        Layer.create_translation_table!({ name: :string, info: :text,
                                           legend: :text, title: :string,
                                           data_units: :string,
                                           processing: :string,
                                           description: :text })

        query = "INSERT INTO layer_translations (name, info, legend, title, data_units, processing, description, layer_id, locale)
                 SELECT  name, info, legend, title, data_units, processing, description, id, 'en'
                 FROM layers"

        ActiveRecord::Base.connection.execute(query)

        query = "ALTER TABLE layers
                 DROP COLUMN name,
                 DROP COLUMN info,
                 DROP COLUMN legend,
                 DROP COLUMN data_units,
                 DROP COLUMN processing,
                 DROP COLUMN description"

        ActiveRecord::Base.connection.execute(query)

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
