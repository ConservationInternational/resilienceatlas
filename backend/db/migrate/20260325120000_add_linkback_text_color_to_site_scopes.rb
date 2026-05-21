class AddLinkbackTextColorToSiteScopes < ActiveRecord::Migration[7.2]
  def change
    add_column :site_scopes, :linkback_text_color, :string
  end
end
