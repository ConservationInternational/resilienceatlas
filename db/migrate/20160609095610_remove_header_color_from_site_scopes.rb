class RemoveHeaderColorFromSiteScopes < ActiveRecord::Migration[6.0]
  def change
    remove_column :site_scopes, :header_color
  end
end
