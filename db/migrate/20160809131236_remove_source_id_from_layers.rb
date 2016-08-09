class RemoveSourceIdFromLayers < ActiveRecord::Migration
  def change
    remove_column :layers, :source_id
  end
end
