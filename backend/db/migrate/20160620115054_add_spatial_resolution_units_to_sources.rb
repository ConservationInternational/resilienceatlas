class AddSpatialResolutionUnitsToSources < ActiveRecord::Migration[6.0]
  def change
    add_column :sources, :spatial_resolution_units, :string
  end
end
