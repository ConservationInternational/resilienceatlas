class AddSuperadminRoleAndSiteScopeAuthorization < ActiveRecord::Migration[7.2]
  def up
    # Extend the role integer enum — new values: superadmin=3, contributor=4.
    # manager (integer 1) is removed; reassign those rows to admin (integer 0).
    execute "UPDATE admin_users SET role = 0 WHERE role = 1"

    create_table :admin_user_site_scopes do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.references :site_scope, null: false, foreign_key: true
      t.timestamps
    end

    add_index :admin_user_site_scopes, [:admin_user_id, :site_scope_id], unique: true,
      name: "index_admin_user_site_scopes_unique"
  end

  def down
    drop_table :admin_user_site_scopes
    # manager role reassignment is irreversible
  end
end
