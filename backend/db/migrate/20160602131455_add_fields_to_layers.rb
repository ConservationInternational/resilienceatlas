class AddFieldsToLayers < ActiveRecord::Migration[6.0]
  def change
    add_reference :layers, :source, index: true
    add_column :layers, :title, :string
    add_column :layers, :start_date, :datetime
    add_column :layers, :end_date, :datetime
    add_column :layers, :spatial_resolution, :string
    add_column :layers, :spatial_resolution_units, :string
    add_column :layers, :temporal_resolution, :string
    add_column :layers, :temporal_resolution_units, :string
    add_column :layers, :data_units, :string
    add_column :layers, :update_frequency, :string
    add_column :layers, :version, :string
    add_column :layers, :processing, :string
  end
end
