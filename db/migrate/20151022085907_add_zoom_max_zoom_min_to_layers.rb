class AddZoomMaxZoomMinToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :zoom_max, :integer, default: 100
    add_column :layers, :zoom_min, :integer, default: 0
  end
end
