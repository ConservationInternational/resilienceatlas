class AddInteractionConfigToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :interaction_config, :text
  end
end
