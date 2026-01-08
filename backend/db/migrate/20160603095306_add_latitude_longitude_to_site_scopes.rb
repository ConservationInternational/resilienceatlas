class AddLatitudeLongitudeToSiteScopes < ActiveRecord::Migration[6.0]
  def change
    add_column :site_scopes, :latitude, :float
    add_column :site_scopes, :longitude, :float
  end
end
