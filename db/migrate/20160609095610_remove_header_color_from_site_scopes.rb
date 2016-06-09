class RemoveHeaderColorFromSiteScopes < ActiveRecord::Migration
  def change
    remove_column :site_scopes, :header_color
  end
end
