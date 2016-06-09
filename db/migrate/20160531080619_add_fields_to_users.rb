class AddFieldsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :first_name,        :string
    add_column :users, :last_name,         :string
    add_column :users, :phone,             :string
    add_column :users, :organization,      :string
    add_column :users, :organization_role, :string
  end
end
