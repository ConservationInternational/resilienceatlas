class AddInteractionConfigToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :interaction_config, :text
  end
end
