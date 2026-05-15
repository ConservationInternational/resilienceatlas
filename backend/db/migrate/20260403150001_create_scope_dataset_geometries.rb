class CreateScopeDatasetGeometries < ActiveRecord::Migration[7.2]
  def up
    create_table :scope_dataset_geometries do |t|
      t.references :scope_dataset, null: false, foreign_key: true
      t.string :unit_id, null: false
      t.jsonb :properties, null: false, default: {}
      t.timestamps
    end

    execute <<-SQL
      ALTER TABLE scope_dataset_geometries
        ADD COLUMN geom geometry(MultiPolygon, 4326) NOT NULL;
    SQL

    add_index :scope_dataset_geometries, [:scope_dataset_id, :unit_id],
      name: "idx_scope_dataset_geom_dataset_unit"
    add_index :scope_dataset_geometries, :geom, using: :gist
  end

  def down
    drop_table :scope_dataset_geometries
  end
end
