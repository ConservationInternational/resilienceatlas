# Configure RGeo for PostGIS
RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # Set the default factory for spatial columns
  config.default = RGeo::Cartesian.preferred_factory(srid: 4326)
end

# Configure the PostGIS adapter
# Note: In newer versions of activerecord-postgis-adapter (10.x+),
# the spatial_column_options configuration is handled differently
if defined?(ActiveRecord::ConnectionAdapters::PostGISAdapter)
  # The adapter configuration is now handled through database.yml
  # or through connection-specific settings rather than global adapter settings
  Rails.logger.info "PostGIS adapter loaded successfully"
end
