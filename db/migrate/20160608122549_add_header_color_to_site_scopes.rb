class AddHeaderColorToSiteScopes < ActiveRecord::Migration[6.0]
  def change
    add_column :site_scopes, :header_color, :string
  end
end
