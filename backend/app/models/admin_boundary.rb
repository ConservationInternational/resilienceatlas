class AdminBoundary < ApplicationRecord
  validates :admin_level, presence: true, inclusion: {in: [0, 1, 2]}
  validates :geom, presence: true

  scope :countries, -> { where(admin_level: 0) }
  scope :provinces, -> { where(admin_level: 1) }
  scope :districts, -> { where(admin_level: 2) }
  scope :at_level, ->(level) { where("admin_level <= ?", level) }

  # Returns the maximum admin level that should be shown at a given zoom level.
  # zoom 0-4: only countries (ADM0)
  # zoom 5-7: + provinces/states (ADM1)
  # zoom 8+:  + districts (ADM2)
  def self.admin_level_for_zoom(zoom)
    case zoom
    when 0..4 then 0
    when 5..7 then 1
    else 2
    end
  end

  # Generates a Mapbox Vector Tile (MVT) for the given tile coordinates.
  # Uses ST_AsMVT and ST_AsMVTGeom from PostGIS 3+.
  #
  # Performance: geometries are simplified proportional to zoom level so that
  # low-zoom tiles don't process millions of vertices they can't display.
  #
  # @param z [Integer] zoom level
  # @param x [Integer] tile column
  # @param y [Integer] tile row
  # @return [String] binary MVT protobuf data
  def self.mvt_tile(z, x, y)
    max_level = admin_level_for_zoom(z)

    # Simplification tolerance in EPSG:4326 degrees, proportional to the
    # size of a single pixel at this zoom level.  The tile is 4096 units
    # wide and covers 360/2^z degrees of longitude, so one pixel ≈
    # 360 / (2^z * 4096) degrees.  We simplify at ~4 px tolerance.
    tolerance = 360.0 / (2**z * 1024)

    sql = <<~SQL
      SELECT ST_AsMVT(tile, 'boundaries', 4096, 'mvt_geom') AS mvt
      FROM (
        SELECT
          name,
          iso_code,
          admin_level,
          ST_AsMVTGeom(
            ST_Transform(
              ST_SimplifyPreserveTopology(geom, $5),
              3857
            ),
            ST_TileEnvelope($1, $2, $3),
            4096,
            64,
            true
          ) AS mvt_geom
        FROM admin_boundaries
        WHERE geom && ST_Transform(ST_TileEnvelope($1, $2, $3), 4326)
          AND admin_level <= $4
      ) AS tile
      WHERE mvt_geom IS NOT NULL
    SQL

    result = connection.exec_query(
      sql,
      "MVT Tile",
      [z.to_i, x.to_i, y.to_i, max_level.to_i, tolerance],
      prepare: false
    )
    row = result.rows.first
    return "".b if row.nil?

    mvt = row[0]
    return "".b if mvt.nil?

    # PG adapter may return binary string directly or hex-encoded bytea
    if mvt.is_a?(String) && mvt.encoding == Encoding::ASCII_8BIT
      mvt
    elsif mvt.is_a?(String) && mvt.start_with?("\\x")
      [mvt[2..]].pack("H*")
    else
      mvt.force_encoding(Encoding::ASCII_8BIT)
    end
  end
end
