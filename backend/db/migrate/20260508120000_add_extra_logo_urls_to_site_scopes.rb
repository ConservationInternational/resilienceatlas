class AddExtraLogoUrlsToSiteScopes < ActiveRecord::Migration[7.2]
  def change
    add_column :site_scopes, :logo_url_2, :text
    add_column :site_scopes, :logo_url_3, :text
    add_column :site_scopes, :logo_url_4, :text
    add_column :site_scopes, :logo_url_5, :text
  end
end
