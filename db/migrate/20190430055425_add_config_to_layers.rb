class AddConfigToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :layer_config, :text
  end
end
