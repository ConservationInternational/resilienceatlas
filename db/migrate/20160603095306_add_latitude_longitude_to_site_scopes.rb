class AddLatitudeLongitudeToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :latitude, :float
    add_column :site_scopes, :longitude, :float
  end
end
