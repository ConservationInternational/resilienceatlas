class AddResourceUrlToSources < ActiveRecord::Migration[6.0]
  def change
    add_column :sources, :license_url, :text
  end
end
