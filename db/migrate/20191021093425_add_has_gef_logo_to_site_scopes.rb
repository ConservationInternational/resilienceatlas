class AddHasGefLogoToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :has_gef_logo, :boolean
  end
end
