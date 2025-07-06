class CreateTranslations < ActiveRecord::Migration[6.0]
  def change
    reversible do |dir|
      dir.up do
        # Create layer_translations table manually to avoid model loading issues
        create_table :layer_translations do |t|
          t.references :layer, null: false, foreign_key: true
          t.string :locale, null: false
          t.timestamps null: false
          
          t.string :name
          t.text :info
          t.text :legend
          t.string :title
          t.string :data_units
          t.string :processing
          t.text :description
        end
        
        add_index :layer_translations, [:layer_id, :locale], unique: true

        # Copy existing data
        execute <<-SQL
          INSERT INTO layer_translations (name, info, legend, title, data_units, processing, description, layer_id, locale, created_at, updated_at)
          SELECT name, info, legend, title, data_units, processing, description, id, 'en', NOW(), NOW()
          FROM layers
        SQL

        # Remove old columns
        remove_column :layers, :name
        remove_column :layers, :info
        remove_column :layers, :legend
        remove_column :layers, :data_units
        remove_column :layers, :processing
        remove_column :layers, :description

        # Create layer_group_translations table manually
        create_table :layer_group_translations do |t|
          t.references :layer_group, null: false, foreign_key: true
          t.string :locale, null: false
          t.timestamps null: false
          
          t.string :name
          t.text :info
        end
        
        add_index :layer_group_translations, [:layer_group_id, :locale], unique: true

        # Copy existing layer group data
        execute <<-SQL
          INSERT INTO layer_group_translations (name, info, layer_group_id, locale, created_at, updated_at)
          SELECT name, info, id, 'en', NOW(), NOW()
          FROM layer_groups
        SQL

        # Remove old layer group columns
        remove_column :layer_groups, :name
        remove_column :layer_groups, :info
      end

      dir.down do
        # Add columns back to layers
        add_column :layers, :name, :string
        add_column :layers, :info, :text
        add_column :layers, :legend, :text
        add_column :layers, :data_units, :string
        add_column :layers, :processing, :string
        add_column :layers, :description, :text

        # Copy data back
        execute <<-SQL
          UPDATE layers 
          SET name = lt.name, 
              info = lt.info, 
              legend = lt.legend, 
              data_units = lt.data_units, 
              processing = lt.processing, 
              description = lt.description
          FROM layer_translations lt 
          WHERE layers.id = lt.layer_id AND lt.locale = 'en'
        SQL

        # Add columns back to layer_groups
        add_column :layer_groups, :name, :string
        add_column :layer_groups, :info, :text

        # Copy layer group data back
        execute <<-SQL
          UPDATE layer_groups 
          SET name = lgt.name, 
              info = lgt.info
          FROM layer_group_translations lgt 
          WHERE layer_groups.id = lgt.layer_group_id AND lgt.locale = 'en'
        SQL

        drop_table :layer_translations
        drop_table :layer_group_translations
      end
    end
  end
end
