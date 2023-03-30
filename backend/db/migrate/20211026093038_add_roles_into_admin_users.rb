class AddRolesIntoAdminUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :admin_users, :role, :integer, default: 0
  end
end
