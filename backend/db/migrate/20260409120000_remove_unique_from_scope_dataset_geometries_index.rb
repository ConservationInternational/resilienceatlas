class RemoveUniqueFromScopeDatasetGeometriesIndex < ActiveRecord::Migration[7.2]
  def change
    remove_index :scope_dataset_geometries, name: "idx_scope_dataset_geom_dataset_unit"
    add_index :scope_dataset_geometries, [:scope_dataset_id, :unit_id],
      name: "idx_scope_dataset_geom_dataset_unit"
  end
end
