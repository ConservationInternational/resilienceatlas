class CreateUserDownloads < ActiveRecord::Migration[6.1]
  def change
    create_table :user_downloads do |t|
      t.string :subdomain
      t.integer :user_id
      t.integer :layer_id

      t.timestamps
    end
  end
end
