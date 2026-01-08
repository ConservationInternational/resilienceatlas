class RemoveSourceIdFromLayers < ActiveRecord::Migration[6.0]
  def change
    remove_column :layers, :source_id
  end
end
