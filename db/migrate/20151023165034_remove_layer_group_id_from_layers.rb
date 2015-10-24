class RemoveLayerGroupIdFromLayers < ActiveRecord::Migration
  def self.up
    #remove_column :layers, :layer_group_id
  end
  def self.down
    add_column :layers, :layer_group_id, :integer
  end
end
