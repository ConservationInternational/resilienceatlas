class CreateCategory < ActiveRecord::Migration
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      t.timestamps

      t.index :name
    end
  end
end
