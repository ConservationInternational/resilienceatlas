class AddAttributions < ActiveRecord::Migration
  def change
    add_column :layers, :dataset_shortname, :string
    add_column :layers, :dataset_source_url, :text
  end
end
