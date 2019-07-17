class AddAnalyticsToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :analytics_code, :string
  end
end
