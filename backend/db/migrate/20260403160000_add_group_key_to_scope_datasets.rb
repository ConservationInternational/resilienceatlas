class AddGroupKeyToScopeDatasets < ActiveRecord::Migration[7.2]
  def change
    add_column :scope_datasets, :group_key, :string
    add_column :scope_datasets, :variant_label, :string
    add_index :scope_datasets, [:site_scope_id, :group_key]
  end
end
