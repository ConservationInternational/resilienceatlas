class AddZoomMaxZoomMinToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :zoom_max, :integer, default: 100
    add_column :layers, :zoom_min, :integer, default: 0
  end
end
