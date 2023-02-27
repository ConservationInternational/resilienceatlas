class CreateLayers < ActiveRecord::Migration[6.0]
  def change
    create_table :layers do |t|
      t.integer :layer_group_id
      t.string :name, null: false
      t.string :slug, null: false
      t.string :layer_type
      t.integer :zindex
      t.boolean :active
      t.integer :order
      t.string :color
      t.text :info
      t.string :layer_provider
      t.text :css
      t.text :interactivity
      t.float :opacity
      t.text :query
      t.timestamps null: false
    end
    add_index :layers, :layer_group_id
  end
end
