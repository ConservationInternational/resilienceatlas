class AddSiteScopesAttributes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :color, :string
    add_column :site_scopes, :subdomain, :string
    add_column :site_scopes, :has_analysis, :boolean, default: false
  end
end
