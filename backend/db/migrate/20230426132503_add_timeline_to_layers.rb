class AddTimelineToLayers < ActiveRecord::Migration[7.0]
  def change
    add_column :layers, :timeline, :boolean, default: false
    add_column :layers, :timeline_overlap, :string
    add_column :layers, :timeline_steps, :date, array: true, default: []
    add_column :layers, :timeline_start_date, :date
    add_column :layers, :timeline_end_date, :date
    add_column :layers, :timeline_default_date, :date
    add_column :layers, :timeline_period, :string
    add_column :layers, :timeline_format, :string, default: "%Y-%m-%d"
  end
end
