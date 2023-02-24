class CreateSitePages < ActiveRecord::Migration[6.0]
  def change
    create_table :site_pages do |t|
      t.string :title
      t.text :body
      t.integer :priority
      t.integer :site_scope_id

      t.timestamps null: false
    end
    add_index :site_pages, :site_scope_id
    add_index :site_pages, [:title, :site_scope_id], unique: true
  end
end
