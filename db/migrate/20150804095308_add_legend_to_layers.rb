class AddLegendToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :legend, :text
  end
end
