class AddDownloadToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :download, :boolean, default: false
  end
end
