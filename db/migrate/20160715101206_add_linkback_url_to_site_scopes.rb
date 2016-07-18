class AddLinkbackUrlToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :linkback_url, :text
  end
end
