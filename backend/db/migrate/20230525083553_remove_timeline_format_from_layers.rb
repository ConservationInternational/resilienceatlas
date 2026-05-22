class RemoveTimelineFormatFromLayers < ActiveRecord::Migration[7.0]
  def change
    remove_column :layers, :timeline_format
  end
end
