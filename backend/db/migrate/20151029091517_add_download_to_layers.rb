class AddDownloadToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :download, :boolean, default: false
  end
end
