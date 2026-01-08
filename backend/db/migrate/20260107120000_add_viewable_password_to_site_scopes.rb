class AddViewablePasswordToSiteScopes < ActiveRecord::Migration[7.2]
  def change
    # Add column to store password in a decryptable format for admin viewing
    # This is in addition to encrypted_password (bcrypt hash) used for authentication
    add_column :site_scopes, :encrypted_viewable_password, :text
  end
end
