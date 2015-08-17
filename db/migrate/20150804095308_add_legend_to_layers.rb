class AddLegendToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :legend, :text
  end
end
