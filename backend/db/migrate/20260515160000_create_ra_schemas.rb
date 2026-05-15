# frozen_string_literal: true

# Create the three application schemas and move existing public tables into ra_app.
#
# Schema layout after this migration:
#
#   ra_app    — all Rails-managed tables (layers, users, admin_boundaries, etc.)
#   ra_vector — externally-managed vector / CartoDB attribute tables
#   ra_raster — externally-managed raster data
#   public    — PostGIS extension objects only (spatial_ref_sys, geometry_columns, …)
#
# The database.yml schema_search_path is set to ra_app,ra_vector,ra_raster,public
# so unqualified SQL resolves across all four schemas in that priority order.
# Rails only dumps/creates tables in ra_app (the first schema); ra_vector and
# ra_raster are excluded from schema.rb by PostgisSchemaFilter.
class CreateRaSchemas < ActiveRecord::Migration[7.2]
  # Objects that must remain in public — PostGIS extension tables/views and
  # Rails internal tracking tables.
  KEEP_IN_PUBLIC = %w[
    spatial_ref_sys
    geography_columns
    geometry_columns
    raster_columns
    raster_overviews
    schema_migrations
    ar_internal_metadata
  ].freeze

  def up
    execute "CREATE SCHEMA IF NOT EXISTS ra_app"
    execute "CREATE SCHEMA IF NOT EXISTS ra_vector"
    execute "CREATE SCHEMA IF NOT EXISTS ra_raster"

    move_tables("public", "ra_app")
  end

  def down
    move_tables("ra_app", "public")

    execute "DROP SCHEMA IF EXISTS ra_raster"
    execute "DROP SCHEMA IF EXISTS ra_vector"
    execute "DROP SCHEMA IF EXISTS ra_app"
  end

  private

  def move_tables(from_schema, to_schema)
    tables = connection.execute(<<~SQL).map { |row| row["tablename"] }
      SELECT tablename
      FROM pg_tables
      WHERE schemaname = '#{from_schema}'
        AND tablename NOT IN ('#{KEEP_IN_PUBLIC.join("', '")}')
    SQL

    tables.each do |table|
      say "#{from_schema}.#{table} → #{to_schema}.#{table}"
      execute %(ALTER TABLE "#{from_schema}"."#{table}" SET SCHEMA "#{to_schema}")
    end
  end
end
