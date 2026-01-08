class AddConfigToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :layer_config, :text
  end
end
