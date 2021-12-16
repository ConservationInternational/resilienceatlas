class AddAnalyticsToSiteScopes < ActiveRecord::Migration[6.0]
  def change
    add_column :site_scopes, :analytics_code, :string
  end
end
