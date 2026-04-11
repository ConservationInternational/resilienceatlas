class AddHasSearchToSiteScopes < ActiveRecord::Migration[7.2]
  def change
    add_column :site_scopes, :has_search, :boolean, default: true, null: false
  end
end
