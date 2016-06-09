class AddHeaderThemeToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :header_theme, :string
  end
end
