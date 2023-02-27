class AddSlugToSitePages < ActiveRecord::Migration[6.0]
  def change
    add_column :site_pages, :slug, :string
    add_index :site_pages, :slug, unique: true
  end
end
