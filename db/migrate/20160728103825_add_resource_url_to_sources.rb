class AddResourceUrlToSources < ActiveRecord::Migration
  def change
    add_column :sources, :license_url, :text
  end
end
