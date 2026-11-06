# Repairs imported vector geometries so Martin can serve them as clean MVT tiles.
#
# Two problems are handled, in this order:
#
# 1. Antimeridian-crossing polygons. Many global datasets (hotspots, KBAs,
#    WDPA) contain rings that jump from ~+180 to ~-180 longitude instead of
#    being split at the antimeridian. In planar WGS84 such a ring covers the
#    whole width of the map, so every tile renders a horizontal band across the
#    world. Each affected polygon component is shifted into 0..360 space, made
#    valid there, and split back at 180 with ST_WrapX. This runs before
#    ST_MakeValid because "repairing" a crossing ring in -180..180 space
#    destroys its shape. Components that legitimately span the globe (e.g.
#    Antarctica) are left alone because shifting them does not make them
#    narrower.
#
# 2. Invalid geometries, which crash the PostGIS backend in ST_AsMVTGeom.
module VectorGeometryRepair
  WGS84_SRID = 4326
  # Column types whose rows may contain polygons that can be normalized.
  ANTIMERIDIAN_COLUMN_TYPES = %w[MULTIPOLYGON GEOMETRY].freeze
  COLLECTION_EXTRACT_TYPES = {
    "MULTIPOINT" => 1,
    "MULTILINESTRING" => 2,
    "MULTIPOLYGON" => 3
  }.freeze

  module_function

  # Repairs every geometry column of a base table.
  #
  # @return [Hash] { antimeridian: Integer, invalid: Integer } rows updated
  def repair_table!(conn, schema:, table:, batch_size: nil)
    geometry_columns(conn, schema, table).each_with_object({antimeridian: 0, invalid: 0}) do |col, totals|
      result = repair_column!(conn, schema: schema, table: table, column: col["f_geometry_column"], batch_size: batch_size)
      totals[:antimeridian] += result[:antimeridian]
      totals[:invalid] += result[:invalid]
    end
  end

  def repair_column!(conn, schema:, table:, column:, batch_size: nil)
    info = column_info(conn, schema, table, column)
    return {antimeridian: 0, invalid: 0} unless info

    {
      antimeridian: repair_antimeridian!(conn, schema: schema, table: table, column: column, info: info, batch_size: batch_size),
      invalid: repair_invalid!(conn, schema: schema, table: table, column: column, info: info, batch_size: batch_size)
    }
  end

  def repair_antimeridian!(conn, schema:, table:, column:, info: nil, batch_size: nil)
    info ||= column_info(conn, schema, table, column)
    return 0 unless info && antimeridian_repairable?(info)

    update_rows!(
      conn,
      q_table: quote_table(conn, schema, table),
      set_sql: "#{conn.quote_column_name(column)} = #{antimeridian_normalization_sql(conn.quote_column_name(column))}",
      where_sql: antimeridian_candidate_sql(conn.quote_column_name(column)),
      batch_size: batch_size
    )
  end

  def repair_invalid!(conn, schema:, table:, column:, info: nil, batch_size: nil)
    info ||= column_info(conn, schema, table, column)
    return 0 unless info

    q_col = conn.quote_column_name(column)
    update_rows!(
      conn,
      q_table: quote_table(conn, schema, table),
      set_sql: "#{q_col} = #{make_valid_sql(q_col, info["type"])}",
      where_sql: "#{q_col} IS NOT NULL AND NOT ST_IsValid(#{q_col})",
      batch_size: batch_size
    )
  end

  # True when the component's ring jumps across the antimeridian, i.e. it
  # spans more than half the globe in -180..180 space but becomes narrower when
  # its longitudes are shifted into 0..360.
  def crosses_antimeridian_sql(geom_sql)
    shifted = "ST_ShiftLongitude(#{geom_sql})"
    "(ST_XMax(#{geom_sql}) - ST_XMin(#{geom_sql}) > 180 " \
      "AND ST_XMax(#{shifted}) - ST_XMin(#{shifted}) <= 180)"
  end

  def antimeridian_candidate_sql(q_col)
    "#{q_col} IS NOT NULL " \
      "AND ST_GeometryType(#{q_col}) IN ('ST_Polygon', 'ST_MultiPolygon') " \
      "AND ST_XMax(#{q_col}) - ST_XMin(#{q_col}) > 180 " \
      "AND EXISTS (SELECT 1 FROM ST_Dump(#{q_col}) AS am_part " \
      "WHERE #{crosses_antimeridian_sql("am_part.geom")})"
  end

  def antimeridian_normalization_sql(q_col)
    "(SELECT ST_Multi(ST_CollectionExtract(ST_Collect(" \
      "CASE WHEN #{crosses_antimeridian_sql("am_part.geom")} " \
      "THEN ST_WrapX(ST_MakeValid(ST_ShiftLongitude(am_part.geom)), 180, -360) " \
      "ELSE am_part.geom END), 3)) " \
      "FROM ST_Dump(#{q_col}) AS am_part)"
  end

  # ST_MakeValid can return a GeometryCollection, which typed Multi* columns
  # reject. Keep only the components matching the column type.
  def make_valid_sql(q_col, column_type)
    extract_type = COLLECTION_EXTRACT_TYPES[column_type.to_s.upcase]
    return "ST_MakeValid(#{q_col})" unless extract_type

    "ST_Multi(ST_CollectionExtract(ST_MakeValid(#{q_col}), #{extract_type}))"
  end

  def antimeridian_repairable?(info)
    info["srid"].to_i == WGS84_SRID && ANTIMERIDIAN_COLUMN_TYPES.include?(info["type"].to_s.upcase)
  end

  def column_info(conn, schema, table, column)
    conn.select_one(
      "SELECT type, srid FROM geometry_columns " \
      "WHERE f_table_schema = #{conn.quote(schema)} " \
      "AND f_table_name = #{conn.quote(table)} " \
      "AND f_geometry_column = #{conn.quote(column)} LIMIT 1"
    )
  end

  def geometry_columns(conn, schema, table)
    conn.select_all(
      "SELECT f_geometry_column FROM geometry_columns " \
      "WHERE f_table_schema = #{conn.quote(schema)} " \
      "AND f_table_name = #{conn.quote(table)} " \
      "ORDER BY f_geometry_column"
    ).to_a
  end

  def quote_table(conn, schema, table)
    "#{conn.quote_table_name(schema)}.#{conn.quote_table_name(table)}"
  end

  # Updates matching rows in one statement, or in ctid batches when
  # batch_size is set (for tables too large to rewrite in one transaction).
  def update_rows!(conn, q_table:, set_sql:, where_sql:, batch_size:)
    unless batch_size
      return conn.exec_update("UPDATE #{q_table} SET #{set_sql} WHERE #{where_sql}")
    end

    candidate_count = conn.select_value("SELECT count(*) FROM #{q_table} WHERE #{where_sql}").to_i
    return 0 if candidate_count.zero?

    updated = 0
    # Bound the loop in case a repaired row still matches the predicate.
    ((candidate_count / batch_size) + 1).times do
      n = conn.exec_update(
        "UPDATE #{q_table} SET #{set_sql} " \
        "WHERE ctid IN (SELECT ctid FROM #{q_table} WHERE #{where_sql} LIMIT #{Integer(batch_size)})"
      )
      updated += n
      break if n < batch_size
    end
    updated
  end
end
