class LayersSources < ActiveRecord::Migration[6.0]
  def change
    create_table :layers_sources, id: false do |t|
      t.integer :layer_id
      t.integer :source_id
    end
    add_index :layers_sources, :layer_id
    add_index :layers_sources, :source_id
  end
end
