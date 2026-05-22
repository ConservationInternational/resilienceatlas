class AddLinkbackTextToSiteScopes < ActiveRecord::Migration[6.0]
  def change
    add_column :site_scopes, :linkback_text, :text
  end
end
