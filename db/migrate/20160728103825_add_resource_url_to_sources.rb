class AddResourceUrlToSources < ActiveRecord::Migration
  def change
    add_column :sources, :resource_url, :text
  end
end
