class CreateMapMenuEntry < ActiveRecord::Migration
  def change
    create_table :map_menu_entries do |t|
      t.string :label, optional: false
      t.string :link, optional: true
      t.integer :position, optional: false

      t.timestamps
    end
  end
end
