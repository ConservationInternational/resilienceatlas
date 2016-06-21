class AddSpatialResolutionUnitsToSources < ActiveRecord::Migration
  def change
    add_column :sources, :spatial_resolution_units, :string
  end
end
