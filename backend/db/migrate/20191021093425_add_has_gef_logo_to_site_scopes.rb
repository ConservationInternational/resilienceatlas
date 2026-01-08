class AddHasGefLogoToSiteScopes < ActiveRecord::Migration[6.0]
  def change
    add_column :site_scopes, :has_gef_logo, :boolean
  end
end
