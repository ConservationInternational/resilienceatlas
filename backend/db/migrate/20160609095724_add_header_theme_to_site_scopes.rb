class AddHeaderThemeToSiteScopes < ActiveRecord::Migration[6.0]
  def change
    add_column :site_scopes, :header_theme, :string
  end
end
