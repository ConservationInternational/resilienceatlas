class AddAncestryToMapMenuEntries < ActiveRecord::Migration[6.0]
  def change
    add_column :map_menu_entries, :ancestry, :string
    add_index :map_menu_entries, :ancestry
  end
end
