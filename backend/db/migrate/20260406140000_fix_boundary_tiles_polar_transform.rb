# Fixes two PostGIS errors when Martin renders boundary tiles:
#
# 1. "transform: tolerance condition error (-20)" — EPSG:3857 (Web
#    Mercator) is undefined beyond ±85.051129° latitude.  Geometries
#    that extend past that limit (e.g. Antarctica) crash ST_Transform.
#
# 2. "TopologyException: Self-intersection" — some imported geometries
#    have subtle self-intersections that break spatial operations.
#
# Fix: repair geometries with ST_MakeValid and clip to the Web Mercator
# valid extent.  This is a one-time data fix — the boundaries:import rake
# task now applies the same cleanup during import so future data is clean.
class FixBoundaryTilesPolarTransform < ActiveRecord::Migration[7.2]
  WEB_MERCATOR_BOUNDS = "ST_MakeEnvelope(-180, -85.051129, 180, 85.051129, 4326)"

  def up
    # Fix existing data: repair invalid geometries and clip to Web Mercator extent
    execute <<~SQL
      UPDATE admin_boundaries
      SET geom = ST_Multi(ST_CollectionExtract(
        ST_Intersection(
          ST_MakeValid(geom),
          #{WEB_MERCATOR_BOUNDS}
        ),
        3
      ))
      WHERE NOT ST_IsValid(geom)
         OR NOT ST_CoveredBy(geom, #{WEB_MERCATOR_BOUNDS});
    SQL
  end

  def down
    # Data fix is not reversible — re-import boundaries to restore original geometries
  end
end
