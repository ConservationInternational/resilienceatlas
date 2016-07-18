class AddLinkbackTextToSiteScopes < ActiveRecord::Migration
  def change
    add_column :site_scopes, :linkback_text, :text
  end
end
