class AddHeaderColorToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :header_color, :string
  end
end
