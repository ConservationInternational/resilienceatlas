class AddLocateLayerIconClassToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :locate_layer, :boolean, default: false
    add_column :layers, :icon_class, :string
  end
end
