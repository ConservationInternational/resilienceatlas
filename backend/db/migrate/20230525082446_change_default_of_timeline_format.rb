class ChangeDefaultOfTimelineFormat < ActiveRecord::Migration[7.0]
  def change
    change_column_default :layers, :timeline_format, "yyyy-MM-dd"
    Layer.where(timeline_format: "%Y-%m-%d").update_all timeline_format: "yyyy-MM-dd"
  end
end
