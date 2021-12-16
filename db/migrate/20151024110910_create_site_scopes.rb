class CreateSiteScopes < ActiveRecord::Migration[6.0]
  def change
    create_table :site_scopes do |t|
      t.string :name
    end
    add_column :layer_groups, :site_scope_id, :integer, default: 1
    add_index :layer_groups, :site_scope_id
  end
end
