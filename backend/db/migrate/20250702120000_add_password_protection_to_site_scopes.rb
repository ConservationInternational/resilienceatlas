class AddPasswordProtectionToSiteScopes < ActiveRecord::Migration[7.0]
  def change
    add_column :site_scopes, :password_protected, :boolean, default: false, null: false
    add_column :site_scopes, :username, :string
    add_column :site_scopes, :encrypted_password, :string

    add_index :site_scopes, :password_protected
  end
end
