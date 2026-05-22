class RemoveAnalyticsCodeFromSiteScopes < ActiveRecord::Migration[7.0]
  def change
    remove_column :site_scopes, :analytics_code
  end
end
