class CreateScopeDatasetGeometries < ActiveRecord::Migration[7.2]
  def change
    create_table :scope_dataset_geometries do |t|
      t.references :scope_dataset, null: false, foreign_key: true
      t.string :unit_id, null: false
      t.jsonb :properties, null: false, default: {}
      t.multi_polygon :geom, srid: 4326, null: false
      t.timestamps
    end

    add_index :scope_dataset_geometries, [:scope_dataset_id, :unit_id], unique: true,
      name: "idx_scope_dataset_geom_dataset_unit"
    add_index :scope_dataset_geometries, :geom, using: :gist
  end
end
