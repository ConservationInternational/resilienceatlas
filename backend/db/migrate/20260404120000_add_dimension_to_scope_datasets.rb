class AddDimensionToScopeDatasets < ActiveRecord::Migration[7.2]
  def change
    add_column :scope_datasets, :dimension, :string
    add_column :scope_datasets, :dimension_config, :jsonb, default: {}
    add_index :scope_datasets, [:site_scope_id, :dimension]
  end
end
