class RemoveInteractivityFromLayers < ActiveRecord::Migration[7.2]
  def change
    remove_column :layers, :interactivity, :text
  end
end
