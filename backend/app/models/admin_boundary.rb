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
  # @param z [Integer] zoom level
  # @param x [Integer] tile column
  # @param y [Integer] tile row
  # @return [String] binary MVT protobuf data
  def self.mvt_tile(z, x, y)
    max_level = admin_level_for_zoom(z)

    sql = <<~SQL
      SELECT ST_AsMVT(tile, 'boundaries', 4096, 'mvt_geom') AS mvt
      FROM (
        SELECT
          name,
          iso_code,
          admin_level,
          ST_AsMVTGeom(
            geom,
            ST_TileEnvelope($1, $2, $3),
            4096,
            256,
            true
          ) AS mvt_geom
        FROM admin_boundaries
        WHERE geom && ST_TileEnvelope($1, $2, $3)
          AND admin_level <= $4
      ) AS tile
    SQL

    result = connection.exec_query(
      sql,
      "MVT Tile",
      [z.to_i, x.to_i, y.to_i, max_level.to_i],
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
