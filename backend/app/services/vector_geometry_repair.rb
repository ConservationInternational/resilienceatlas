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
#
# GEOS validity checks on very large polygons can use more memory than the
# database container allows, so the kernel OOM-kills the PostgreSQL backend.
# Batched mode (batch_size + on_crash) contains that: see repair_column!.
module VectorGeometryRepair
  class TooManyCrashes < StandardError; end

  CHECKS = %i[antimeridian invalid].freeze
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
  # @return [Hash] { antimeridian:, invalid:, skipped: } row counts
  def repair_table!(conn, schema:, table:, **options)
    geometry_columns(conn, schema, table).each_with_object(empty_result) do |col, totals|
      result = repair_column!(conn, schema: schema, table: table, column: col["f_geometry_column"], **options)
      totals.merge!(result) { |_key, a, b| a + b }
    end
  end

  # checks:      subset of CHECKS to run.
  # batch_size:  process rows in fixed ctid slices of this size, so each
  #              statement only evaluates geometry functions on those rows.
  # on_crash:    called with the error when a statement kills the PostgreSQL
  #              backend; must wait for the database to recover and return a
  #              fresh connection. The failing slice is then retried row by
  #              row, and rows that still crash are left unchanged and counted
  #              as skipped. Requires batch_size.
  # max_crashes: raise TooManyCrashes after this many crashes in one column,
  #              so a pathological table cannot keep restarting the database.
  def repair_column!(conn, schema:, table:, column:, checks: CHECKS, batch_size: nil, on_crash: nil, max_crashes: 5)
    info = column_info(conn, schema, table, column)
    return empty_result unless info

    q_table = quote_table(conn, schema, table)
    q_col = conn.quote_column_name(column)
    steps = []
    if checks.include?(:antimeridian) && antimeridian_repairable?(info)
      steps << [:antimeridian, "#{q_col} = #{antimeridian_normalization_sql(q_col)}", antimeridian_candidate_sql(q_col)]
    end
    if checks.include?(:invalid)
      steps << [:invalid, "#{q_col} = #{make_valid_sql(q_col, info["type"])}", "#{q_col} IS NOT NULL AND NOT ST_IsValid(#{q_col})"]
    end

    result = empty_result
    crashes = 0
    crash_handler = on_crash && lambda do |error|
      crashes += 1
      raise TooManyCrashes, "#{crashes} database crashes repairing #{q_table}.#{q_col}: #{error.message.lines.first.strip}" if crashes > max_crashes

      conn = on_crash.call(error)
    end

    steps.each do |key, set_sql, where_sql|
      updated, skipped = update_rows!(
        -> { conn }, q_table: q_table, set_sql: set_sql, where_sql: where_sql,
        batch_size: batch_size, on_crash: crash_handler
      )
      result[key] += updated
      result[:skipped] += skipped
    end
    result
  end

  # After a backend crash PostgreSQL restarts (and under Docker Swarm the
  # database task may be replaced, so its hostname briefly stops resolving).
  # Polls until it accepts queries again and returns a fresh connection.
  def wait_for_database(timeout: 300, interval: 10)
    deadline = Time.current + timeout
    begin
      ActiveRecord::Base.connection_pool.disconnect!
      conn = ActiveRecord::Base.connection
      conn.select_value("SELECT 1")
      conn
    rescue => e
      raise "PostgreSQL did not recover within #{timeout}s: #{e.message.lines.first.strip}" if Time.current > deadline

      sleep interval
      retry
    end
  end

  def empty_result
    {antimeridian: 0, invalid: 0, skipped: 0}
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

  # Returns [rows_updated, rows_skipped]. conn_ref returns the current
  # connection, which on_crash may replace.
  def update_rows!(conn_ref, q_table:, set_sql:, where_sql:, batch_size:, on_crash:)
    unless batch_size
      return [conn_ref.call.exec_update("UPDATE #{q_table} SET #{set_sql} WHERE #{where_sql}"), 0]
    end

    # Listing ctids evaluates no geometry functions, so it cannot OOM. Rows
    # get new ctids when updated, so they are never revisited.
    ctids = conn_ref.call.select_values("SELECT ctid::text FROM #{q_table}")
    updated = 0
    skipped = 0

    ctids.each_slice(Integer(batch_size)) do |slice|
      updated += update_ctids!(conn_ref.call, q_table, set_sql, where_sql, slice)
    rescue TooManyCrashes
      raise
    rescue => e
      raise unless on_crash && crash?(e)

      on_crash.call(e)
      slice.each do |ctid|
        updated += update_ctids!(conn_ref.call, q_table, set_sql, where_sql, [ctid])
      rescue TooManyCrashes
        raise
      rescue => row_error
        raise unless crash?(row_error)

        on_crash.call(row_error)
        skipped += 1
      end
    end
    [updated, skipped]
  end

  def update_ctids!(conn, q_table, set_sql, where_sql, ctids)
    tids = "ARRAY[#{ctids.map { |c| conn.quote(c) }.join(",")}]::tid[]"
    conn.exec_update("UPDATE #{q_table} SET #{set_sql} WHERE ctid = ANY(#{tids}) AND (#{where_sql})")
  end

  # Lost connections (backend killed, database restarting) as opposed to
  # ordinary SQL errors, which should propagate.
  def crash?(error)
    error.is_a?(ActiveRecord::ConnectionNotEstablished) ||
      error.is_a?(ActiveRecord::ConnectionFailed) ||
      error.is_a?(PG::ConnectionBad) ||
      error.is_a?(PG::UnableToSend) ||
      error.cause.is_a?(PG::ConnectionBad) ||
      error.cause.is_a?(PG::UnableToSend) ||
      error.message.match?(/server closed the connection|terminating connection|recovery mode|connecting with your hostname/i)
  end
end
