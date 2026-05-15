class AddFaviconUrlToSiteScopes < ActiveRecord::Migration[7.2]
  def change
    add_column :site_scopes, :favicon_url, :text unless column_exists?(:site_scopes, :favicon_url)
  end
end
