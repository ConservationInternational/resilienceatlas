class AddHeaderColorLogoUrlToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :header_color, :string
    add_column :site_scopes, :logo_url, :text
  end
end
