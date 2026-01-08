class DeviseTokenAuthCreateAdminUsers < ActiveRecord::Migration[6.1]
  def change
    ## Required
    add_column :admin_users, :provider, :string, null: false, default: "email"
    add_column :admin_users, :uid, :string, null: false, default: ""

    ## Recoverable
    add_column :admin_users, :allow_password_change, :boolean, default: false

    ## User Info
    add_column :admin_users, :name, :string
    add_column :admin_users, :nickname, :string
    add_column :admin_users, :image, :string

    ## Tokens
    add_column :admin_users, :tokens, :json

    ## Confirmable
    add_column :admin_users, :confirmation_token, :string
    add_column :admin_users, :confirmed_at, :datetime
    add_column :admin_users, :confirmation_sent_at, :datetime
    add_column :admin_users, :unconfirmed_email, :string # Only if using reconfirmable
  end
end
