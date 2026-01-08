class AddZoomLevelToSiteScopes < ActiveRecord::Migration[6.0]
  def change
    add_column :site_scopes, :zoom_level, :integer, default: 3
  end
end
