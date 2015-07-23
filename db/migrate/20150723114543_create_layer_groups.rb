class CreateLayerGroups < ActiveRecord::Migration
  def change
    create_table :layer_groups do |t|
      t.string :name
      t.integer :super_group_id
      t.string :slug
      t.string :layer_group_type
      t.string :category
      t.boolean :active
      t.integer :order
      t.text :info

      t.timestamps null: false
    end
    add_index :layer_groups, :super_group_id
  end
end
