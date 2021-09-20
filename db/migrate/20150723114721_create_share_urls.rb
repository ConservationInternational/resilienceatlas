class CreateShareUrls < ActiveRecord::Migration[6.0]
  def change
    create_table :share_urls do |t|
      t.string :uid
      t.text :body
      t.timestamps null: false
    end
  end
end
