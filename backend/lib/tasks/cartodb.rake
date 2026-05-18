# Rake tasks for importing CartoDB data and updating formerly CartoDB layer rows.
#
# Workflow:
#   1. Run `export_vectors_bash.sh export` on the CartoDB server to upload .gpkg files to S3.
#   2. Run `export_tables_bash.sh export` for any non-spatial tables (optional).
#   3. Run `rake cartodb:import_tables` to download and load those files into PostgreSQL.
#      Vectors (.gpkg) are imported via ogr2ogr; non-spatial tables (.csv.gz) via COPY.
#   4. Run `rake cartodb:update_layer_references` to update the formerly CartoDB layer rows.
#   5. Manually review each layer in the admin UI: set a valid layer_provider and layer_config,
#      then re-publish.
#
# The vector export script produces GeoPackage files named {schema}_{table}.gpkg (e.g.
# public_yam_gh.gpkg) at a separate S3 prefix from the non-spatial CSV.GZ tables.
# Both local-directory (CSV only) and S3 sources are supported.

# ---------------------------------------------------------------------------
# Shared helpers (at file scope so all tasks can call them)
# ---------------------------------------------------------------------------

module CartodbRakeHelpers
  SQL_TABLE_STOP_WORDS = %w[
    select where lateral values unnest generate_series on using inner left right full cross
  ].freeze

  # Extract bare table names from FROM / JOIN clauses of a SQL string.
  # Handles schema-qualified names (schema.table) and SQL aliases.
  # Returns an array of lowercase table-name strings, deduplicated.
  def self.extract_table_names_from_sql(sql)
    return [] if sql.blank?

    cte_names = sql.scan(/(?:\bWITH\b|,)\s*"?(\w+)"?\s+AS\s*\(/i).flatten.map(&:downcase)
    tables = []

    sql.scan(/\bFROM\s+(.+?)(?=\bWHERE\b|\bGROUP\s+BY\b|\bHAVING\b|\bORDER\s+BY\b|\bLIMIT\b|\bUNION\b|\bEXCEPT\b|\bINTERSECT\b|;|$)/im)
      .flatten
      .each do |from_clause|
        from_clause.split(",").each do |entry|
          match = entry.match(/\A\s*(?:"?\w+"?\.)?"?(\w+)"?/)
          tables << match[1].downcase if match
        end
      end

    tables.concat(sql.scan(/\bJOIN\s+(?:"?\w+"?\.)?"?(\w+)"?/i).flatten.map(&:downcase))

    tables
      .reject { |t| SQL_TABLE_STOP_WORDS.include?(t) || cte_names.include?(t) }
      .uniq
  end

  def self.raster_layer?(layer, sql)
    layer.css.to_s.match?(/raster-colorizer|raster-opacity|raster-scaling/i) ||
      sql.to_s.match?(/the_raster|st_clip\s*\(/i)
  end

  def self.build_cog_source_url(bucket, prefix, table_name)
    normalized_prefix = prefix.to_s.sub(%r{\A/+}, "")
    normalized_prefix = "#{normalized_prefix}/" if normalized_prefix.present? && !normalized_prefix.end_with?("/")
    "s3://#{bucket}/#{normalized_prefix}#{table_name}.tif"
  end

  def self.parse_hex_color(color)
    # Strip surrounding double-quotes (e.g. "#e31a1c" from some CSS)
    value = color.to_s.strip.gsub(/\A"|"\z/, "")
    return [0, 0, 0, 0] if value.blank? ||
      value.casecmp?("transparent") ||
      value.casecmp?("#transparent")

    # rgba(r, g, b, a) or rgb(r, g, b)
    if (m = value.match(/\Argba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([0-9.]+))?\s*\)\z/i))
      r, g, b = m[1].to_i, m[2].to_i, m[3].to_i
      a = m[4] ? (m[4].to_f * 255).round.clamp(0, 255) : 255
      return [r, g, b, a]
    end

    v = value.downcase
    if v.match?(/\A#[0-9a-f]{3}\z/)
      r = (v[1] * 2).to_i(16)
      g = (v[2] * 2).to_i(16)
      b = (v[3] * 2).to_i(16)
      return [r, g, b, 255]
    end

    if v.match?(/\A#[0-9a-f]{6}\z/)
      return [v[1, 2].to_i(16), v[3, 2].to_i(16), v[5, 2].to_i(16), 255]
    end

    # Bare decimal integer: Mapnik packed-RGB format (e.g. 874914 = #0D59A2)
    if value.match?(/\A\d+\z/)
      n = value.to_i
      return [(n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF, 255]
    end

    nil
  end

  # Build a TiTiler colormap from CSS stops.
  #
  # For "linear" (default) mode: returns a 0-255 indexed gradient hash
  #   {"key" => [r,g,b,a]} that TiTiler interpolates after rescaling.
  #
  # For "discrete" or "exact" mode: returns an explicit interval array
  #   [[[lower, upper], [r,g,b,a]], ...] that TiTiler applies directly to
  #   raw pixel values without any rescaling.
  def self.build_titiler_colormap(stops, mode: "linear")
    return nil if stops.blank?

    if %w[discrete exact].include?(mode.to_s.downcase)
      build_interval_colormap(stops, exact: mode.to_s.downcase == "exact")
    else
      build_gradient_colormap(stops)
    end
  end

  # Gradient colormap for linear/default mode.
  # Normalises stop values to 0-255 key space; TiTiler interpolates between
  # defined keys after rescaling raw pixel values with the rescale parameter.
  def self.build_gradient_colormap(stops)
    values = stops.map { |stop| stop[:value] }
    min = values.min
    max = values.max
    range = max - min
    used_keys = {}

    colormap = stops.each_with_object({}) do |stop, memo|
      rgba = parse_hex_color(stop[:color])
      next unless rgba

      key = if range.zero?
        0
      else
        (((stop[:value] - min) / range) * 255).round.clamp(0, 255)
      end

      while used_keys[key] && key < 255
        key += 1
      end
      while used_keys[key] && key > 0
        key -= 1
      end

      used_keys[key] = true
      memo[key.to_s] = rgba
    end

    colormap.presence
  end

  # Interval colormap for discrete/exact mode.
  # Returns [[[lower, upper], [r,g,b,a]], ...] — TiTiler applies colours
  # directly to raw pixel values (no rescale).
  #
  #   discrete: stop n covers [v_n, v_{n+1}) — step-function assignment
  #   exact:    stop n covers [v_n, v_n+1)   — only exact integer values match
  def self.build_interval_colormap(stops, exact: false)
    sorted = stops.sort_by { |s| s[:value] }
    colormap = []

    sorted.each_with_index do |stop, i|
      rgba = parse_hex_color(stop[:color])
      next unless rgba

      lower = stop[:value]
      upper = if exact
        lower + 1
      elsif i + 1 < sorted.length
        sorted[i + 1][:value]
      else
        lower + 1  # last stop: extend one unit beyond its value
      end

      colormap << [[lower, upper], rgba]
    end

    colormap.presence
  end

  def self.translate_raster_css(css)
    return {} if css.blank?

    opacity = css[/raster-opacity\s*:\s*([0-9.]+)/i, 1]
    mode = css[/raster-colorizer-default-mode\s*:\s*([a-z]+)/i, 1]&.downcase
    # The color argument may be rgba(r,g,b,a) which contains commas, so we
    # must match it as a unit before falling back to the plain [^,)] pattern.
    # Some CSS blocks omit the outer closing ) on the last stop() call (the
    # block's } terminates first), so the trailing ) is made optional (\)?).
    # Edge cases also handled: "#rrggbb" quoted hex, #transparent, bare integers.
    stops = css.scan(/stop\(\s*(-?\d*\.?\d+(?:e[+-]?\d+)?)\s*,\s*(rgba?\([^)]+\)|transparent|#transparent|"#[0-9a-fA-F]+"|#[0-9a-fA-F]+|\d+)(?:\s*,\s*([a-z]+))?\s*\)?/i).map do |value, color, extra|
      {
        value: value.to_f,
        color: color.to_s.strip,
        exact: extra.to_s.strip.downcase == "exact"
      }
    end

    result = {}
    result["opacity"] = opacity.to_f if opacity.present?
    result["mode"] = mode if mode.present?

    if stops.any?
      min = stops.map { |stop| stop[:value] }.min
      max = stops.map { |stop| stop[:value] }.max
      result["colormap"] = build_titiler_colormap(stops, mode: mode || "linear")
      # Gradient colormaps (linear mode) require rescale to normalise pixel
      # values into the 0-255 key space.  Interval colormaps (discrete/exact)
      # use raw pixel values directly, so rescale must NOT be set.
      unless %w[discrete exact].include?(mode.to_s)
        result["rescale"] = "#{min},#{max}" if min && max
      end
    end

    result.compact
  end

  # Parse { schema:, table: } from a {schema}_{table}.csv.gz filename.
  # Splits only on the FIRST underscore because CartoDB schema names are short
  # (e.g. "public") while table names may themselves contain underscores.
  def self.parse_export_filename(basename)
    name = basename.sub(/\.csv\.gz\z/, "")
    idx = name.index("_")
    return nil unless idx

    {schema: name[0...idx], table: name[(idx + 1)..]}
  end

  # Parse { schema:, table: } from a {schema}_{table}.gpkg filename.
  # Same convention as parse_export_filename but for GeoPackage vector exports.
  def self.parse_vector_filename(basename)
    name = basename.sub(/\.gpkg\z/, "")
    idx = name.index("_")
    return nil unless idx

    {schema: name[0...idx], table: name[(idx + 1)..]}
  end

  # Load the tables.csv manifest produced by the export script.
  # Returns: { "public_foo.csv.gz" => { schema: "public", table: "foo" }, ... }
  def self.load_manifest(path)
    require "csv"
    return {} unless File.exist?(path.to_s)

    CSV.foreach(path, headers: true).each_with_object({}) do |row, h|
      next if row["schema"].blank? || row["table"].blank?

      key = "#{row["schema"]}_#{row["table"]}.csv.gz"
      h[key] = {schema: row["schema"], table: row["table"]}
    end
  end

  # Sample up to +limit+ data rows from a gzipped CSV file and infer a
  # PostgreSQL column type for each column.  Falls back to TEXT for anything
  # that does not look like a plain integer, decimal, or boolean.
  def self.infer_column_types(gz_path, limit: 1_000)
    require "csv"
    require "zlib"

    col_samples = {}

    Zlib::GzipReader.open(gz_path) do |gz|
      csv = CSV.new(gz, headers: true)
      csv.each_with_index do |row, idx|
        break if idx >= limit

        row.each do |col, val|
          col_samples[col] ||= []
          col_samples[col] << val if val && !val.empty?
        end
      end
    end

    col_samples.transform_values do |vals|
      next "text" if vals.empty?

      if vals.all? { |v| v.match?(/\A-?\d+\z/) }
        "bigint"
      elsif vals.all? { |v| v.match?(/\A-?\d+\.?\d*(?:[eE][+-]?\d+)?\z/) }
        "double precision"
      elsif vals.all? { |v| v.match?(/\A(?:true|false|t|f|yes|no)\z/i) }
        "boolean"
      else
        "text"
      end
    end
  end

  # Strip CartoDB-internal columns (cartodb_id, the_geom_webmercator, the_geom)
  # from a SELECT list and fix up any resulting comma artifacts.
  CARTODB_INTERNAL_COLS = %w[cartodb_id the_geom_webmercator the_geom].freeze

  def self.strip_cartodb_columns(sql)
    return sql if sql.blank?

    cleaned = sql.dup
    CARTODB_INTERNAL_COLS.each do |col|
      # Remove:  alias.col,   col,   (trailing comma variants)
      cleaned.gsub!(/\b\w+\.#{col}\b[ \t]*,[ \t]*/i, "")
      cleaned.gsub!(/\b#{col}\b[ \t]*,[ \t]*/i, "")
      # Remove:  , alias.col   , col   (leading comma variants)
      cleaned.gsub!(/,[ \t]*\b\w+\.#{col}\b/i, "")
      cleaned.gsub!(/,[ \t]*\b#{col}\b/i, "")
      # Remove bare remnants (last column or only column)
      cleaned.gsub!(/\b\w+\.#{col}\b/i, "")
      cleaned.gsub!(/\b#{col}\b/i, "")
    end

    # Fix artefacts: "SELECT ," → "SELECT", ", FROM" → " FROM", double commas
    cleaned.gsub!(/\bSELECT\s*,/i, "SELECT")
    cleaned.gsub!(/,\s*\bFROM\b/i, " FROM")
    cleaned.gsub!(/[ \t]*,[ \t]*,[ \t]*/m, ", ")
    cleaned.strip
  end

  # Schema-qualify unqualified table names in FROM/JOIN clauses of a SQL query.
  # Handles aliases (FROM foo f, FROM foo AS f) — only the table reference in
  # FROM/JOIN is qualified; subsequent alias references in ON/WHERE are left as-is,
  # which is correct because PostgreSQL resolves them from the scoped FROM list.
  def self.qualify_table_names_in_sql(sql, schema, table_names)
    return sql if sql.blank?

    qualified = sql.dup
    # Longest names first to prevent partial-name clobber (e.g. "foo" inside "foobar")
    table_names.sort_by { |t| -t.length }.each do |tbl|
      escaped = Regexp.escape(tbl)
      # Match FROM/JOIN <table> but not when already schema-qualified (ra_vector.table)
      qualified.gsub!(
        /\b(FROM|JOIN)\s+("?#{escaped}"?)(?=\s|,|\z|;)/i
      ) { "#{$1} #{schema}.#{$2}" }
    end
    qualified
  end

  # Returns true if the SQL query needs a PostgreSQL view (has WHERE, JOIN,
  # GROUP BY, etc.) rather than being a plain single-table reference.
  def self.needs_view?(sql)
    return false if sql.blank?
    sql.match?(/\b(?:WHERE|JOIN|GROUP\s+BY|HAVING|UNION|EXCEPT|INTERSECT|LIMIT|ORDER\s+BY)\b/i)
  end

  # Extract a SQL query from a CartoDB-native layer_config JSON blob.
  # CartoDB stored the SQL in two common shapes:
  #   {"body":{"sql":"SELECT ..."},...}   ← most common
  #   {"sql":"SELECT ...", ...}           ← older/alternate format
  # Returns nil when no recognisable SQL is found or the JSON is invalid.
  def self.extract_sql_from_cartodb_config(layer_config_json)
    return nil if layer_config_json.blank?
    cfg = JSON.parse(layer_config_json)
    cfg.dig("body", "sql").presence || cfg["sql"].presence
  rescue JSON::ParserError
    nil
  end

  # Translate CartoDB vector CSS (CartoCSS) to OL PathOptions format used by
  # the martin-layer-ol.js plugin.  Returns a PathOptions hash suitable for
  # storage as a single entry in the martin layer `body.styles` object.
  #
  # Mapping:
  #   polygon-fill    → fillColor
  #   polygon-opacity → fillOpacity
  #   line-color      → color
  #   line-width      → weight
  #   line-opacity    → opacity
  #
  # Conditional rules with attribute filters are stored as a "conditions" array
  # and resolved by the frontend style-converter.js at render time.
  #
  # String equality filter:
  #   [prop="val"]  → { "when" => { "prop" => "val" }, ...overrides }
  # Numeric comparison filter:
  #   [prop <= N]   → { "when" => { "prop" => { "op" => "<=", "val" => N } }, ...overrides }
  #
  # Multi-filter rules ([a="x"][b <= 3]) are AND-combined in the `when` object.
  # Zoom filters ([zoom >= N]) are stripped — zoom-adaptive styling cannot be
  # serialised to static JSON; the base rule provides the default appearance.
  #
  # Returns {} when no recognisable declarations are found.
  def self.translate_vector_css(css)
    return {} if css.blank?

    base_props = {}
    zoom_hint_props = {}  # polygon/line props from zoom-only blocks (lower priority)
    conditional_rules = []

    # Each block: #selector(optional_chained_filters) { declarations }
    # (?:\s*\[[^\]]*\])* captures zero or more [filter] groups with optional
    # leading whitespace (e.g. '#layer [prop<=90]' has a space before the filter)
    css.scan(/#[\w-]+((?:\s*\[[^\]]*\])*)\s*\{([^}]+)\}/m).each do |filter_chain, declarations|
      props = {}
      declarations.scan(/([\w-]+)\s*:\s*([^;]+)/).each do |prop, val|
        props[prop.strip] = val.strip
      end

      if filter_chain.nil? || filter_chain.strip.empty?
        base_props.merge!(props)
      else
        # Parse each individual [filter] in the chained selector
        filters = filter_chain.scan(/\[([^\]]+)\]/).map(&:first)

        # Separate zoom-based filters (rendering hints) from data property filters
        data_filters = filters.reject { |f| f.match?(/\Azoom\s*[<>=!]/i) }

        # Rules that only constrain zoom (no data filter) — keep polygon/line props
        # as lower-priority fallback base hints (Martin renders at all zoom levels)
        if data_filters.empty?
          zoom_hint_props.merge!(props)
          next
        end

        # Build the `when` conditions hash from data filters
        when_hash = {}
        data_filters.each do |f|
          if (m = f.match(/(\w+)\s*=\s*["']([^"']+)["']/))
            # String equality: [prop="val"]
            when_hash[m[1]] = m[2]
          elsif (m = f.match(/(\w+)\s*([<>]=?|!=)\s*([-\d.]+)/))
            # Numeric comparison: [prop <= N]
            when_hash[m[1]] = {"op" => m[2], "val" => m[3].to_f}
          end
        end

        next unless when_hash.any?
        conditional_rules << {when: when_hash, styles: props}
      end
    end

    # Zoom-only block props are lower priority than explicit unfiltered base props
    base_props = zoom_hint_props.merge(base_props)

    path_opts = {}

    # Stroke / line properties
    path_opts["color"] = base_props["line-color"] if base_props["line-color"].present?
    path_opts["weight"] = base_props["line-width"].to_f if base_props["line-width"].present?
    path_opts["opacity"] = base_props["line-opacity"].to_f if base_props["line-opacity"].present?

    # Fill opacity from base rule
    path_opts["fillOpacity"] = base_props["polygon-opacity"].to_f if base_props["polygon-opacity"].present?

    # Fill color: prefer base rule; fall back to first non-transparent conditional fill
    fill_color = base_props["polygon-fill"]
    if fill_color.blank? || fill_color =~ /\Atransparent\z/i
      first_fill = conditional_rules.find do |r|
        r[:styles]["polygon-fill"].to_s.present? &&
          r[:styles]["polygon-fill"] !~ /\Atransparent\z/i
      end
      fill_color = first_fill&.dig(:styles, "polygon-fill")
    end

    if fill_color.present? && fill_color !~ /\Atransparent\z/i
      path_opts["fillColor"] = fill_color
      path_opts["fill"] = true
    end

    # Point marker properties — used when no polygon/line styling is present
    # (CartoDB marker-* maps to Leaflet VectorGrid circleMarker pathOptions)
    if path_opts["color"].blank? && base_props["marker-line-color"].present?
      path_opts["color"] = base_props["marker-line-color"]
      path_opts["weight"] = base_props["marker-line-width"].to_f if base_props["marker-line-width"].present?
      path_opts["opacity"] = [base_props["marker-line-opacity"].to_f, 1.0].min if base_props["marker-line-opacity"].present?
    end
    if path_opts["fillOpacity"].blank? && base_props["marker-fill-opacity"].present?
      path_opts["fillOpacity"] = [base_props["marker-fill-opacity"].to_f, 1.0].min
    end
    if path_opts["fillColor"].blank?
      marker_fill = base_props["marker-fill"].to_s
      if marker_fill.present? && marker_fill !~ /\Atransparent\z/i
        path_opts["fillColor"] = marker_fill
        path_opts["fill"] = true
      end
    end

    # Build conditions array from conditional rules
    if conditional_rules.any?
      conds = conditional_rules.filter_map do |rule|
        pfill = rule[:styles]["polygon-fill"].to_s.strip
        popac = rule[:styles]["polygon-opacity"]
        lcolor = rule[:styles]["line-color"]
        overrides = {}

        if pfill.match?(/\Atransparent\z/i)
          overrides["fillOpacity"] = 0
          overrides["fill"] = false
        elsif pfill.present?
          overrides["fillColor"] = pfill
          overrides["fill"] = true
          overrides["fillOpacity"] = popac.to_f if popac.present?
        elsif popac.present?
          overrides["fillOpacity"] = popac.to_f
        end

        overrides["color"] = lcolor if lcolor.present? && !overrides.key?("color")
        next if overrides.empty?
        {"when" => rule[:when]}.merge(overrides)
      end
      path_opts["conditions"] = conds if conds.any?
    end

    path_opts
  end

  # ---------------------------------------------------------------------------
  # Interactivity helpers
  # ---------------------------------------------------------------------------

  # Build interaction_config for a COG layer.
  # Uses TiTiler's /cog/point endpoint for pixel value lookup on click.
  def self.build_cog_interaction_config
    {
      "output" => [{"column" => "values.0", "property" => "Value", "type" => "number"}],
      "config" => {"url" => "{{titilerUrl}}/cog/point/{{lng}}/{{lat}}?url={{cogUrl}}"}
    }
  end

  # Columns to exclude when building Martin interaction output from table schema.
  MARTIN_SKIP_COLS = %w[cartodb_id the_geom the_geom_webmercator created_at updated_at ogc_fid].freeze

  # Build interaction_config for a Martin vector layer by inspecting the PostGIS table.
  # Returns a hash with "output" array ready for JSON serialisation, or nil when the
  # table has no interesting columns (e.g. pure geometry tables).
  def self.build_martin_interaction_config(table_name, conn, target_schema)
    rows = conn.execute(
      "SELECT column_name FROM information_schema.columns " \
      "WHERE table_schema = #{conn.quote(target_schema)} " \
      "AND table_name = #{conn.quote(table_name)} " \
      "ORDER BY ordinal_position"
    )
    cols = rows.map { |r| r["column_name"] }
               .reject { |c| MARTIN_SKIP_COLS.include?(c) || c.match?(/\A(?:the_)?geom/i) }
    return nil if cols.empty?

    output = cols.map do |c|
      {"column" => c, "property" => c.tr("_", " ").split.map(&:capitalize).join(" ")}
    end
    {"output" => output}
  rescue => e
    Rails.logger.warn "build_martin_interaction_config(#{table_name}): #{e.message}"
    nil
  end

  # ---------------------------------------------------------------------------
  # ST_CLIP / clip-geometry helpers
  # ---------------------------------------------------------------------------

  # Parse ST_CLIP boundary info from a CartoDB raster SQL string.
  # Handles the three common patterns produced by CartoDB:
  #   A — WITH cte AS (SELECT geom FROM (SELECT * FROM table WHERE ...) AS alias)
  #   B — WITH cte AS (SELECT geom FROM table_name)
  #   C — FROM raster_t alias, boundary_t alias [WHERE ST_INTERSECTS(...)]
  # Returns { table: String, where: String|nil } or nil when not a CLIP query.
  def self.extract_clip_info(sql)
    return nil if sql.blank?
    return nil unless sql.match?(/\bst_clip\s*\(/i)

    # Pattern A: CTE wrapping a subquery with a WHERE clause
    if (m = sql.match(
      /WITH\s+\w+\s+AS\s*\(\s*SELECT\s+\S+\s+FROM\s*\(\s*SELECT\s+\S+\s+FROM\s+(\w+)\s+(WHERE\s+.+?)\)\s+AS\s+\w+/im
    ))
      return {table: m[1].downcase, where: m[2].gsub("''", "'")}
    end

    # Pattern B: Simple CTE directly referencing a table
    if (m = sql.match(/WITH\s+\w+\s+AS\s*\(\s*SELECT\s+\S+\s+FROM\s+(\w+)\s*\)/im))
      return {table: m[1].downcase, where: nil}
    end

    # Pattern C: Comma-joined FROM clause (raster_table alias, boundary_table alias)
    if (m = sql.match(/\bFROM\s+\w+\s+\w+\s*,\s*(\w+)\s+\w+/im))
      return {table: m[1].downcase, where: nil}
    end

    nil
  end

  # Extract the clip boundary geometry from the vector schema and return a
  # simplified GeoJSON Feature (WGS84) suitable for the TiTiler `feature`
  # query parameter.  Returns nil when the boundary table is unavailable.
  #
  # Geometry is simplified to 0.5-degree tolerance (~50 km) to keep tile
  # request URLs manageable.  Exact pixel-perfect clipping is not required
  # here — raster data outside the country extent is already nodata.
  def self.extract_clip_geometry(source_sql, conn, target_schema)
    info = extract_clip_info(source_sql)
    return nil unless info

    table = info[:table]
    where = info[:where]

    exists = conn.select_value(
      "SELECT EXISTS(" \
      "SELECT 1 FROM information_schema.tables " \
      "WHERE table_schema = #{conn.quote(target_schema)} " \
      "AND table_name = #{conn.quote(table)})"
    )
    return nil unless exists

    geom_row = conn.select_one(
      "SELECT f_geometry_column, srid FROM geometry_columns " \
      "WHERE f_table_schema = #{conn.quote(target_schema)} " \
      "AND f_table_name = #{conn.quote(table)} " \
      "LIMIT 1"
    )
    return nil unless geom_row

    geom_col  = geom_row["f_geometry_column"]
    srid      = geom_row["srid"].to_i
    geom_expr = srid == 4326 ? geom_col : "ST_Transform(#{geom_col}, 4326)"

    sql = "SELECT ST_AsGeoJSON(" \
          "ST_SimplifyPreserveTopology(ST_Union(#{geom_expr}), 0.5)) " \
          "FROM \"#{target_schema}\".\"#{table}\""
    sql += " WHERE #{where}" if where.present?

    geom_json = conn.select_value(sql)
    return nil if geom_json.blank?

    {"type" => "Feature", "geometry" => JSON.parse(geom_json)}
  rescue => e
    Rails.logger.warn "extract_clip_geometry(#{table}): #{e.message}"
    nil
  end
end

# ---------------------------------------------------------------------------
# Rake namespace
# ---------------------------------------------------------------------------

namespace :cartodb do
  desc <<~DESC
    Import CartoDB spatial vectors (.gpkg) and non-spatial tables (.csv.gz) from S3 into PostgreSQL.

    Vectors are the primary data source: each {schema}_{table}.gpkg file on S3 is imported
    into the target schema via ogr2ogr.  Non-spatial tables (exported as {schema}_{table}.csv.gz)
    are imported using PostgreSQL COPY.  Only tables actually referenced by formerly CartoDB
    layers (layer_provider=NULL, published=false, query present) are imported.

    Required:
      CARTODB_S3_BUCKET=<bucket>        S3 bucket name

    Optional:
      CARTODB_VECTORS_S3_PREFIX=<p>     S3 prefix for .gpkg vector files
                                          (default: cartodb_exports/vectors/)
      CARTODB_TABLES_S3_PREFIX=<p>      S3 prefix for .csv.gz non-spatial files
                                          (default: cartodb_exports/non-spatial/)
      CARTODB_EXPORT_DIR=<path>         Local directory for .csv.gz files (non-spatial only,
                                          used when CARTODB_S3_BUCKET is not set)
      CARTODB_IMPORT_SCHEMA=<schema>    Target PostgreSQL schema (default: ra_vector)
      FORCE=1                           Overwrite existing tables without prompting

    Usage:
      rake cartodb:import_tables CARTODB_S3_BUCKET=my-bucket
      rake cartodb:import_tables CARTODB_S3_BUCKET=my-bucket \\
        CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \\
        CARTODB_TABLES_S3_PREFIX=cartodb-tables/
  DESC
  task import_tables: :environment do
    require "csv"
    require "zlib"
    require "tmpdir"

    s3_bucket = ENV.fetch("CARTODB_S3_BUCKET", "")
    vectors_prefix = ENV.fetch("CARTODB_VECTORS_S3_PREFIX", "cartodb_exports/vectors/")
    tables_prefix = ENV.fetch("CARTODB_TABLES_S3_PREFIX", "cartodb_exports/non-spatial/")
    export_dir = ENV.fetch("CARTODB_EXPORT_DIR", "")
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    force = ENV["FORCE"] == "1"
    use_s3 = s3_bucket.present?

    # ── Pre-flight checks ───────────────────────────────────────────────────

    if !use_s3 && !(export_dir.present? && Dir.exist?(export_dir))
      abort "ERROR: No export source found.\n" \
            "  Set CARTODB_S3_BUCKET=<bucket> or CARTODB_EXPORT_DIR=<path>.\n" \
            "  (CARTODB_EXPORT_DIR only covers non-spatial .csv.gz tables.)"
    end

    if use_s3 && !system("which aws > /dev/null 2>&1")
      abort "ERROR: aws CLI not found. Install awscli to download from S3."
    end

    unless system("which ogr2ogr > /dev/null 2>&1")
      abort "ERROR: ogr2ogr not found. Install gdal-bin to import .gpkg vector files."
    end

    ar_conn = ActiveRecord::Base.connection
    raw_conn = ar_conn.raw_connection  # PG::Connection – used for streaming COPY

    # Build PG connection string for ogr2ogr
    pg_conn = if ENV["DATABASE_URL"].present?
      # ogr2ogr requires postgresql:// scheme, not postgis://
      ENV["DATABASE_URL"].sub(/\Apostgis:/, "postgresql:")
    else
      cfg = ActiveRecord::Base.connection_db_config.configuration_hash
      host = cfg[:host] || "localhost"
      port = cfg[:port] || 5432
      user = cfg[:username] || "postgres"
      pass = cfg[:password] || ""
      name = cfg[:database]
      "postgresql://#{user}:#{pass}@#{host}:#{port}/#{name}"
    end

    # ── 0. Collect referenced table names from flagged layers ────────────────

    flagged_layers = Layer
      .where(layer_provider: nil, published: false)
      .where(
        "NOT (query IS NULL OR query = '') OR " \
        "layer_config LIKE '%cartodb_migration%' OR " \
        "(layer_config LIKE '%\"body\"%' AND layer_config LIKE '%\"sql\"%')"
      )

    if flagged_layers.empty?
      abort "ERROR: No formerly CartoDB layers found " \
            "(layer_provider=NULL, published=false). Nothing to import."
    end

    referenced_table_names = flagged_layers
      .flat_map do |layer|
        sql = layer.query.presence ||
          CartodbRakeHelpers.extract_sql_from_cartodb_config(layer.layer_config)
        CartodbRakeHelpers.extract_table_names_from_sql(sql)
      end
      .uniq
      .sort

    if referenced_table_names.empty?
      abort "ERROR: #{flagged_layers.count} flagged layer(s) found but no table names " \
            "could be parsed from their queries. Check the query column for those layers."
    end

    puts "Found #{flagged_layers.count} flagged layer(s) referencing " \
         "#{referenced_table_names.size} unique table name(s):"
    referenced_table_names.each { |t| puts "  - #{t}" }
    puts ""

    Dir.mktmpdir("cartodb_import") do |tmpdir|
      # ── 1. Discover available files ─────────────────────────────────────────

      # 1a. Vectors: .gpkg files from S3 vectors prefix
      gpkg_basenames = if use_s3
        puts "Listing s3://#{s3_bucket}/#{vectors_prefix} ..."
        list_output = `aws s3 ls "s3://#{s3_bucket}/#{vectors_prefix}" 2>&1`
        abort "ERROR: aws s3 ls failed for vectors prefix:\n#{list_output}" unless $?.success?
        files = list_output.scan(/(\S+\.gpkg)\s*$/).flatten
        puts "Found #{files.size} .gpkg file(s) at vectors prefix."
        files
      else
        []  # local vector import not supported; set CARTODB_S3_BUCKET
      end

      # 1b. Non-spatial tables: .csv.gz from S3 tables prefix or local directory
      gz_basenames = if use_s3
        puts "Listing s3://#{s3_bucket}/#{tables_prefix} ..."
        list_output = `aws s3 ls "s3://#{s3_bucket}/#{tables_prefix}" 2>&1`
        if $?.success?
          files = list_output.scan(/(\S+\.csv\.gz)\s*$/).flatten
          puts "Found #{files.size} .csv.gz file(s) at tables prefix."
          files
        else
          puts "NOTE: Tables prefix not accessible (#{tables_prefix}): #{list_output.strip}"
          puts "      Non-spatial table import will be skipped."
          []
        end
      elsif export_dir.present? && Dir.exist?(export_dir)
        files = Dir.glob(File.join(export_dir, "*.csv.gz")).map { |f| File.basename(f) }
        puts "Found #{files.size} .csv.gz file(s) in #{export_dir}."
        files
      else
        []
      end

      # ── 2. Build table → file mappings and report coverage ──────────────────

      gpkg_table_to_file = gpkg_basenames.each_with_object({}) do |basename, h|
        info = CartodbRakeHelpers.parse_vector_filename(basename)
        h[info[:table]] = basename if info
      end

      gz_table_to_file = gz_basenames.each_with_object({}) do |basename, h|
        info = CartodbRakeHelpers.parse_export_filename(basename)
        h[info[:table]] = basename if info
      end

      # Vectors take priority; non-spatial tables fill the remainder
      to_import_as_vector = referenced_table_names.select { |t| gpkg_table_to_file.key?(t) }
      to_import_as_table = (referenced_table_names - to_import_as_vector).select { |t| gz_table_to_file.key?(t) }
      missing = referenced_table_names - to_import_as_vector - to_import_as_table

      if missing.any?
        puts "WARNING: The following table(s) are referenced by layers but NOT found on S3:"
        missing.each { |t| puts "  ✗  #{t}" }
        puts ""
      end

      puts "Import plan:"
      puts "  Vectors  (.gpkg)     : #{to_import_as_vector.size}"
      puts "  Non-spatial (.csv.gz): #{to_import_as_table.size}"
      puts "  Missing (not on S3)  : #{missing.size}"
      puts ""

      if to_import_as_vector.empty? && to_import_as_table.empty?
        puts "Nothing to import."
        next
      end

      # ── 3. Ensure the target schema exists ────────────────────────────────

      if target_schema != "public"
        ar_conn.execute("CREATE SCHEMA IF NOT EXISTS \"#{target_schema}\"")
        puts "Ensured schema '#{target_schema}' exists."
      end

      # ── 4. Import vectors (.gpkg via ogr2ogr) ─────────────────────────────

      imported_vectors = []
      skipped_vectors = []
      failed_vectors = []

      total_vectors = to_import_as_vector.size
      to_import_as_vector.each_with_index do |tbl, idx|
        basename = gpkg_table_to_file[tbl]
        info = CartodbRakeHelpers.parse_vector_filename(basename)
        q_table = "\"#{target_schema}\".\"#{tbl}\""

        exists = begin
          ar_conn.table_exists?("#{target_schema}.#{tbl}")
        rescue ActiveRecord::ConnectionFailed, ActiveRecord::DatabaseConnectionError, PG::Error => e
          warn "  DB connection lost before checking #{tbl} (#{e.message}) — reconnecting..."
          sleep 30
          begin
            ActiveRecord::Base.connection_pool.disconnect!
            ar_conn = ActiveRecord::Base.connection
            raw_conn = begin
              ar_conn.raw_connection
            rescue
              nil
            end
          rescue => reconnect_err
            warn "  Reconnect attempt failed: #{reconnect_err.message}. Waiting 30s..."
            sleep 30
          end
          retry
        end

        if exists
          if force
            puts "\n  Table #{q_table} already exists — overwriting (FORCE=1)."
          else
            puts "  Skipping #{tbl} (already exists; set FORCE=1 to overwrite)."
            skipped_vectors << tbl
            next
          end
        end

        puts "\nImporting vector [#{idx + 1}/#{total_vectors}]: #{basename} → #{q_table} ..."

        local_path = File.join(tmpdir, basename)
        print "  Downloading from S3... "
        unless system("aws s3 cp \"s3://#{s3_bucket}/#{vectors_prefix}#{basename}\" \"#{local_path}\"")
          warn "  FAILED: S3 download failed."
          failed_vectors << {table: tbl, file: basename, reason: "S3 download failed"}
          next
        end
        puts "  done (#{File.size(local_path)} bytes)."

        # Try progressively smaller batch sizes on OOM crash (large batches are
        # faster; only pathological files need small ones).
        batch_sizes = [65535, 1000, 100, 10]
        imported = false
        batch_sizes.each do |batch_size|
          puts "  Running ogr2ogr (batch_size=#{batch_size})..."
          success = system(
            "ogr2ogr", "-f", "PostgreSQL",
            "PG:#{pg_conn}",
            local_path,
            "-nln", "#{target_schema}.#{tbl}",
            "-overwrite",
            "-nlt", "PROMOTE_TO_MULTI",
            "-gt", batch_size.to_s,
            "--config", "PG_USE_COPY", "YES"
          )
          if success
            imported = true
            break
          end

          # ogr2ogr failed — PostgreSQL may have crashed (OOM). Wait and reconnect.
          warn "  ogr2ogr failed with batch_size=#{batch_size}."
          warn "  Waiting for PostgreSQL to recover..."
          sleep 30
          10.times do |attempt|
            ActiveRecord::Base.connection_pool.disconnect!
            ar_conn = ActiveRecord::Base.connection
            ar_conn.execute("SELECT 1")
            raw_conn = begin
              ar_conn.raw_connection
            rescue
              nil
            end
            warn "  Reconnected (attempt #{attempt + 1})."
            break
          rescue => e
            if attempt < 9
              warn "  PG not ready yet (attempt #{attempt + 1}/10): #{e.message}. Waiting 15s..."
              sleep 15
            else
              warn "  Reconnect failed after all attempts: #{e.message} — subsequent tables may not import."
            end
          end

          next_batch = batch_sizes[batch_sizes.index(batch_size) + 1]
          warn "  Retrying with smaller batch size #{next_batch}..." if next_batch
        end

        unless imported
          warn "  FAILED: ogr2ogr failed at all batch sizes (65535 → 1000 → 100 → 10)."
          failed_vectors << {table: tbl, file: basename, reason: "ogr2ogr failed (all batch sizes)"}
          begin
            File.delete(local_path)
          rescue
            nil
          end
          next
        end

        row_count = begin
          ar_conn.select_value("SELECT count(*) FROM #{q_table}").to_i
        rescue
          0
        end
        puts "  #{row_count} feature(s) loaded."
        imported_vectors << {file: basename, src_schema: info[:schema], table: tbl, rows: row_count}

        # ── Create spatial index ─────────────────────────────────────────────
        # Martin computes bounding boxes at startup; without a GiST index it
        # times out on every table and drops all sources from the catalog.
        begin
          geom_cols = ar_conn.execute(
            "SELECT f_geometry_column FROM geometry_columns " \
            "WHERE f_table_schema = '#{target_schema}' AND f_table_name = '#{tbl}'"
          ).map { |r| r["f_geometry_column"] }

          geom_cols.each do |col|
            # PostgreSQL identifier limit is 63 bytes; truncate if needed.
            idx_name = "idx_#{tbl}_#{col}"[0, 63]
            print "  Creating spatial index #{idx_name}... "
            ar_conn.execute(
              "CREATE INDEX IF NOT EXISTS \"#{idx_name}\" " \
              "ON #{q_table} USING gist(\"#{col}\")"
            )
            puts "done."

            # ── Repair invalid geometries ──────────────────────────────────
            # Invalid or corrupt geometries crash the PostGIS backend process
            # when Martin runs ST_CurveToLine / ST_Transform / ST_AsMVTGeom,
            # causing "connection closed" tile errors.
            begin
              invalid_count = ar_conn.execute(
                "SELECT count(*) FROM #{q_table} WHERE NOT ST_IsValid(\"#{col}\")"
              ).first["count"].to_i
              if invalid_count > 0
                print "  Repairing #{invalid_count} invalid geometry(ies) in #{col}... "
                ar_conn.execute(
                  "UPDATE #{q_table} SET \"#{col}\" = ST_MakeValid(\"#{col}\") " \
                  "WHERE NOT ST_IsValid(\"#{col}\")"
                )
                puts "done."
              end
            rescue => e
              warn "  WARNING: Could not repair invalid geometries in #{tbl}.#{col}: #{e.message.lines.first.strip}"
              # Reconnect if the PostgreSQL backend process was killed (e.g. OOM on large table)
              begin
                ActiveRecord::Base.connection_pool.disconnect!
                ar_conn = ActiveRecord::Base.connection
              rescue => re
                warn "  WARNING: Reconnect failed: #{re.message.lines.first.strip}"
              end
            end
          end
        rescue => e
          warn "  WARNING: Could not create spatial index for #{tbl}: #{e.message.lines.first.strip}"
          begin
            ActiveRecord::Base.connection_pool.disconnect!
            ar_conn = ActiveRecord::Base.connection
          rescue; end
        end

        # Remove local copy to free disk space in the temp directory
        begin
          File.delete(local_path)
        rescue
          nil
        end
      end

      # ── 5. Import non-spatial tables (.csv.gz via COPY) ───────────────────

      imported_tables = []
      skipped_tables = []
      failed_tables = []

      # Load manifest for better schema/table name inference
      manifest_path = if use_s3
        local_m = File.join(tmpdir, "tables.csv")
        local_m if system("aws s3 cp \"s3://#{s3_bucket}/#{tables_prefix}tables.csv\" \"#{local_m}\" 2>/dev/null")
      elsif export_dir.present?
        File.join(export_dir, "tables.csv")
      end

      manifest = CartodbRakeHelpers.load_manifest(manifest_path)
      puts "Loaded manifest with #{manifest.size} entry(ies)." if manifest.any?

      total_tables = to_import_as_table.size
      to_import_as_table.each_with_index do |tbl, idx|
        basename = gz_table_to_file[tbl]
        info = manifest[basename] || CartodbRakeHelpers.parse_export_filename(basename)
        unless info
          warn "  SKIP #{basename}: cannot parse schema/table from filename."
          skipped_tables << basename
          next
        end

        src_schema = info[:schema]
        q_table = "\"#{target_schema}\".\"#{tbl}\""

        if ar_conn.table_exists?("#{target_schema}.#{tbl}")
          if force
            puts "\n  Table #{q_table} already exists — overwriting (FORCE=1)."
          else
            puts "  Skipping #{tbl} (already exists; set FORCE=1 to overwrite)."
            skipped_tables << basename
            next
          end
        end

        puts "\nImporting table [#{idx + 1}/#{total_tables}]: #{basename} → #{q_table} (original schema: #{src_schema})..."

        gz_path = if use_s3
          local_path = File.join(tmpdir, basename)
          print "  Downloading from S3... "
          unless system("aws s3 cp \"s3://#{s3_bucket}/#{tables_prefix}#{basename}\" \"#{local_path}\"")
            warn "FAILED."
            failed_tables << {file: basename, reason: "S3 download failed"}
            next
          end
          puts "done (#{File.size(local_path)} bytes compressed)."
          local_path
        else
          File.join(export_dir, basename)
        end

        unless File.exist?(gz_path) && File.size(gz_path) > 0
          warn "  FAILED: file not found or empty: #{gz_path}"
          failed_tables << {file: basename, reason: "file not found or empty"}
          next
        end

        # ── Infer column types from a sample of up to 1,000 rows ─────────

        print "  Inferring column types... "
        col_types = CartodbRakeHelpers.infer_column_types(gz_path, limit: 1_000)
        if col_types.empty?
          warn "FAILED (no columns found in CSV)."
          failed_tables << {file: basename, reason: "no columns in CSV"}
          next
        end
        puts "#{col_types.size} column(s) detected."

        # ── Create (or replace) the target table ──────────────────────────

        ar_conn.execute("DROP TABLE IF EXISTS #{q_table}")
        col_defs = col_types.map { |col, type| "\"#{col}\" #{type}" }.join(", ")
        ar_conn.execute("CREATE TABLE #{q_table} (#{col_defs})")

        # ── Stream decompressed CSV directly into COPY FROM STDIN ─────────

        print "  Loading rows... "
        begin
          raw_conn.copy_data(
            "COPY #{q_table} FROM STDIN WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', NULL '')"
          ) do
            Zlib::GzipReader.open(gz_path) do |gz|
              buf = "".b  # binary buffer reused each iteration
              raw_conn.put_copy_data(buf) while gz.read(65_536, buf)
            end
          end

          row_count = ar_conn.select_value("SELECT count(*) FROM #{q_table}").to_i
          puts "#{row_count} row(s) loaded."
          imported_tables << {file: basename, src_schema: src_schema, table: tbl, rows: row_count}
        rescue => e
          warn "FAILED: #{e.message}"
          ar_conn.execute("DROP TABLE IF EXISTS #{q_table}")
          failed_tables << {file: basename, reason: e.message}
        end
      end

      # ── 6. Summary ────────────────────────────────────────────────────────

      puts "\n#{"=" * 60}"
      puts "  CartoDB Import — Summary"
      puts "=" * 60

      total_imported = imported_vectors.size + imported_tables.size
      total_failed = failed_vectors.size + failed_tables.size
      total_skipped = skipped_vectors.size + skipped_tables.size

      puts "  Imported : #{total_imported}"
      imported_vectors.each { |t| puts "    ✓  #{t[:src_schema]}.#{t[:table]} → #{target_schema}.#{t[:table]}  [vector, #{t[:rows]} features]" }
      imported_tables.each { |t| puts "    ✓  #{t[:src_schema]}.#{t[:table]} → #{target_schema}.#{t[:table]}  [table, #{t[:rows]} rows]" }

      if missing.any?
        puts "  Not on S3: #{missing.size}"
        missing.each { |t| puts "    ✗  #{t}" }
      end

      if total_skipped > 0
        puts "  Skipped  : #{total_skipped}"
        skipped_vectors.each { |t| puts "    –  #{t}" }
        skipped_tables.each { |f| puts "    –  #{f}" }
      end

      if total_failed > 0
        puts "  Failed   : #{total_failed}"
        failed_vectors.each { |f| puts "    ✗  #{f[:table]} (#{f[:file]}): #{f[:reason]}" }
        failed_tables.each { |f| puts "    ✗  #{f[:file]}: #{f[:reason]}" }
        abort "\nERROR: #{total_failed} table(s) failed to import — see above."
      end

      puts ""
      puts "Run `rake cartodb:update_layer_references` to update the formerly CartoDB layer rows."
    end
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Update formerly CartoDB layer rows to reference the tables imported by import_tables.

    For each layer flagged by the FlagCartodbLayersForReview migration
    (layer_provider=NULL, published=false, query present) this task:

      1. Parses the CartoDB SQL query to discover referenced table names.
      2. Checks which of those tables now exist in the local PostgreSQL database.
      3. Updates layer_config with a "cartodb_migration" block that records each
         table's import status ("imported" or "missing") and the recommended next steps.
      4. Rewrites the "query" field to strip CartoDB-internal columns
         (cartodb_id, the_geom_webmercator, the_geom) so the SQL is valid against
         the local tables once a new layer_provider is configured.

    Layers remain unpublished (published=false) after this task.  The operator must
    set a valid layer_provider and finalize layer_config in the admin UI before
    re-publishing.

    Optional:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema where tables were imported (default: public)

    Usage:
      rake cartodb:update_layer_references
  DESC
  task update_layer_references: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")

    # Include layers that either:
    #   a) have a SQL query in the query column (standard path), OR
    #   b) already have a cartodb_migration block (idempotent re-run), OR
    #   c) have CartoDB-native layer_config JSON (body.sql / sql keys) —
    #      these were silently skipped before because their query column is blank.
    formerly_cartodb = Layer
      .where(layer_provider: nil, published: false)
      .where(
        "NOT (query IS NULL OR query = '') OR " \
        "layer_config LIKE '%cartodb_migration%' OR " \
        "(layer_config LIKE '%\"body\"%' AND layer_config LIKE '%\"sql\"%')"
      )
      .order(:id)

    if formerly_cartodb.empty?
      puts "No formerly CartoDB layers found " \
           "(layer_provider=NULL, published=false).  Nothing to do."
      next
    end

    puts "Found #{formerly_cartodb.count} formerly CartoDB layer(s).\n\n"

    ar_conn = ActiveRecord::Base.connection
    updated = []
    needs_import = []
    no_tables = []

    formerly_cartodb.each do |layer|
      puts "Layer ##{layer.id} (#{layer.slug}):"

      # ── Resolve the SQL source ──────────────────────────────────────────
      # Prefer the query column; fall back to layer_config.body.sql for
      # layers whose SQL was stored in CartoDB-native JSON format.

      source_sql = if layer.query.present?
        layer.query
      else
        fallback = CartodbRakeHelpers.extract_sql_from_cartodb_config(layer.layer_config)
        puts "  ℹ  query column blank; extracted SQL from layer_config.body.sql" if fallback.present?
        fallback
      end

      # ── Parse table names from the CartoDB SQL ─────────────────────────

      referenced = CartodbRakeHelpers.extract_table_names_from_sql(source_sql)

      if referenced.empty?
        puts "  ⚠  No FROM/JOIN table references found — skipping."
        no_tables << {id: layer.id, slug: layer.slug}
        next
      end

      puts "  Referenced tables : #{referenced.join(", ")}"

      # ── Check which tables are now available locally ────────────────────

      local_tables = referenced.select { |t| ar_conn.table_exists?("#{target_schema}.#{t}") }
      missing_tables = referenced - local_tables

      puts "  Available locally : #{local_tables.any? ? local_tables.join(", ") : "(none)"}"
      puts "  Still missing     : #{missing_tables.any? ? missing_tables.join(", ") : "(none)"}"

      # ── Build the cartodb_migration block for layer_config ─────────────

      table_status = referenced.each_with_object({}) do |t, h|
        h[t] = local_tables.include?(t) ? "imported" : "missing"
      end

      raster_layer = CartodbRakeHelpers.raster_layer?(layer, source_sql)
      raster_tables = raster_layer ? (referenced - local_tables) : []

      migration_block = {
        "status" => if raster_layer
                      raster_tables.any? ? "cog_pending" : "cog_ready"
                    else
                      (local_tables.any? ? "partial" : "pending")
                    end,
        "tables" => table_status,
        "raster" => raster_layer,
        "raster_tables" => raster_tables,
        "source_sql" => source_sql,
        "cleaned_query" => CartodbRakeHelpers.strip_cartodb_columns(source_sql),
        "note" => "Set layer_provider and update layer_config, then set published=true."
      }

      style_config = CartodbRakeHelpers.translate_raster_css(layer.css)
      migration_block["style"] = style_config if style_config.present?

      # Start fresh for the new config (discard old CartoDB body/css keys;
      # preserve only the cartodb_migration block we control)
      new_config = {"cartodb_migration" => migration_block}

      # ── Strip CartoDB-internal columns from the SQL ─────────────────────

      cleaned_query = CartodbRakeHelpers.strip_cartodb_columns(source_sql)

      # ── Persist via update_columns to bypass model validations ─────────
      # (layer_provider=NULL fails presence validation; we must go around it)
      # Also writes cleaned SQL back to query so configure_martin_layers can
      # find and use it regardless of where the original SQL came from.

      layer.update_columns(
        layer_config: new_config.to_json,
        query: cleaned_query
      )

      if local_tables.any?
        puts "  ✓  Updated layer_config and cleaned query."
        updated << {id: layer.id, slug: layer.slug, local: local_tables, missing: missing_tables}
      else
        puts "  ⚠  No referenced tables imported yet — layer_config updated with pending status."
        needs_import << {id: layer.id, slug: layer.slug, missing: missing_tables}
      end
    end

    # ── Summary ─────────────────────────────────────────────────────────────

    puts "\n#{"=" * 56}"
    puts "  Layer Reference Update — Summary"
    puts "=" * 56

    puts "  Updated (≥1 table available): #{updated.size}"
    updated.each do |l|
      puts "    ✓  ##{l[:id]} #{l[:slug]}"
      puts "       Available : #{l[:local].join(", ")}"
      puts "       Missing   : #{l[:missing].join(", ")}" if l[:missing].any?
    end

    if needs_import.any?
      puts "  Pending import (no tables yet): #{needs_import.size}"
      needs_import.each { |l| puts "    ⚠  ##{l[:id]} #{l[:slug]}  — missing: #{l[:missing].join(", ")}" }
    end

    if no_tables.any?
      puts "  No table references found in query: #{no_tables.size}"
      no_tables.each { |l| puts "    ?  ##{l[:id]} #{l[:slug]}" }
    end

    puts ""
    puts "Next steps:"
    puts "  1. For any still-missing tables, re-run rake cartodb:import_tables,"
    puts "     then re-run this task to refresh status."
    puts "  2. Run rake cartodb:configure_cog_layers for raster/COG layers."
    puts "  3. Run rake cartodb:configure_martin_layers for vector/Martin layers."
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Automatically configure raster-like CartoDB layers to use TiTiler-backed COGs.

    For every layer flagged by update_layer_references with raster-style SQL/CSS:
      - Sets layer_provider = "cog"
      - Builds layer_config with body.source/body.sources pointing at converted COGs
      - Translates legacy CartoCSS raster stops into TiTiler render params
      - Publishes the layer when at least one COG source can be inferred

    Optional:
      S3_BUCKET=<bucket>               Bucket containing converted COGs (default: resilienceatlas)
      COG_PREFIX=<prefix>              Prefix for converted COGs (default: cogs/)
      DRY_RUN=1                        Preview changes without saving

    Usage:
      rake cartodb:configure_cog_layers
      rake cartodb:configure_cog_layers DRY_RUN=1
  DESC
  task configure_cog_layers: :environment do
    s3_bucket = ENV.fetch("S3_BUCKET", "resilienceatlas")
    cog_prefix = ENV.fetch("COG_PREFIX", "cogs/")
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    dry_run = ENV["DRY_RUN"] == "1"

    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    candidates = Layer
      .where(layer_provider: nil, published: false)
      .where("layer_config LIKE '%cartodb_migration%'")
      .order(:id)

    if candidates.empty?
      puts "No layers awaiting COG configuration. Nothing to do."
      next
    end

    puts "Found #{candidates.count} layer(s) to review for COG configuration.\n\n"

    configured_count = 0
    published_count = 0
    skipped_count = 0

    candidates.each do |layer|
      puts "Layer ##{layer.id} (#{layer.slug}):"

      config = begin
        layer.layer_config.present? ? JSON.parse(layer.layer_config) : {}
      rescue JSON::ParserError
        {}
      end

      migration = config["cartodb_migration"] || {}
      source_sql = migration["source_sql"].presence || layer.query

      unless CartodbRakeHelpers.raster_layer?(layer, source_sql)
        puts "  - Not a raster-style CartoDB layer; leaving for Martin/manual handling."
        skipped_count += 1
        next
      end

      tables = migration["tables"] || {}
      imported = tables.select { |_, status| status == "imported" }.keys
      raster_tables = Array(migration["raster_tables"]).presence || (tables.keys - imported)

      if raster_tables.empty?
        puts "  - No raster COG tables inferred from migration metadata."
        skipped_count += 1
        next
      end

      sources = raster_tables.map do |table_name|
        CartodbRakeHelpers.build_cog_source_url(s3_bucket, cog_prefix, table_name)
      end

      style = migration["style"].presence || CartodbRakeHelpers.translate_raster_css(layer.css)

      body = {
        "source" => sources.first,
        "sources" => sources,
        "options" => {
          "interactive" => true,
          "maxNativeZoom" => layer.zoom_max || 14
        }
      }
      body["colormap"] = style["colormap"] if style["colormap"].present?
      body["rescale"] = style["rescale"] if style["rescale"].present?
      body["cartocss_mode"] = style["mode"] if style["mode"].present?

      # Extract clip geometry for ST_CLIP layers (boundary polygon stored for TiTiler)
      if source_sql.match?(/\bst_clip\s*\(/i)
        clip_geom = CartodbRakeHelpers.extract_clip_geometry(
          source_sql, ActiveRecord::Base.connection, target_schema
        )
        if clip_geom
          body["clip_geometry"] = clip_geom
          puts "  Clip     : #{clip_geom.dig("geometry", "type")} from #{CartodbRakeHelpers.extract_clip_info(source_sql)&.dig(:table)}"
        else
          puts "  Clip     : ST_CLIP detected but boundary table not available — skipped"
        end
      end

      migration["status"] = "configured_cog"
      migration["raster"] = true
      migration["raster_tables"] = raster_tables
      migration["style"] = style if style.present?

      new_config = {
        "type" => "tileLayer",
        "body" => body,
        "cartodb_migration" => migration
      }

      interaction_config = CartodbRakeHelpers.build_cog_interaction_config

      puts "  Sources  : #{sources.join(", ")}"
      puts "  Publish  : yes"

      unless dry_run
        layer.update_columns(
          layer_provider: "cog",
          layer_config: new_config.to_json,
          interaction_config: interaction_config.to_json,
          published: true
        )
      end

      configured_count += 1
      published_count += 1
    end

    puts "\n#{"=" * 56}"
    puts "  COG Configuration#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Configured : #{configured_count}"
    puts "    Published : #{published_count}"
    puts "  Skipped    : #{skipped_count}"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Automatically configure imported CartoDB layers to use the Martin tile server.

    For every layer flagged by update_layer_references (layer_provider=NULL,
    published=false, cartodb_migration block present in layer_config):
      - Sets layer_provider = "martin"
      - Builds layer_config with body.source = "<schema>.<table>"
      - Sets published = true when ALL referenced tables are imported
      - Leaves published = false when some tables are still missing

    Layers with no imported tables at all are skipped.

    Options:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema used during import (default: ra_vector)
      DRY_RUN=1                       Preview changes without saving

    Usage:
      rake cartodb:configure_martin_layers
      rake cartodb:configure_martin_layers DRY_RUN=1
  DESC
  task configure_martin_layers: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    dry_run = ENV["DRY_RUN"] == "1"

    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    ar_conn = ActiveRecord::Base.connection

    candidates = Layer
      .where(layer_provider: nil, published: false)
      .where("layer_config LIKE '%cartodb_migration%'")
      .order(:id)

    if candidates.empty?
      puts "No layers awaiting Martin configuration. Nothing to do."
      next
    end

    puts "Found #{candidates.count} layer(s) to configure.\n\n"

    configured_count = 0
    published_count = 0
    skipped_count = 0
    view_count = 0

    candidates.each do |layer|
      puts "Layer ##{layer.id} (#{layer.slug}):"

      config = begin
        layer.layer_config.present? ? JSON.parse(layer.layer_config) : {}
      rescue JSON::ParserError
        {}
      end

      migration = config["cartodb_migration"]
      unless migration
        puts "  ⚠  No cartodb_migration block — skipping."
        skipped_count += 1
        next
      end

      if migration["raster"]
        puts "  - Raster-like layer detected; use configure_cog_layers instead."
        skipped_count += 1
        next
      end

      tables = migration["tables"] || {}
      imported = tables.select { |_, v| v == "imported" }.keys
      missing = tables.select { |_, v| v == "missing" }.keys

      if imported.empty?
        puts "  ✗  No imported tables yet — skipping."
        skipped_count += 1
        next
      end

      primary_table = imported.first
      all_ready = missing.empty?

      # ── Determine Martin source ──────────────────────────────────────────
      #
      # Simple single-table layers (no WHERE/JOIN complexity) → point directly
      # at the table; Martin streams the whole PostGIS table as vector tiles.
      #
      # Anything with WHERE filters, JOINs, or multiple imported tables → create
      # a PostgreSQL view that preserves the original query logic.  The view is
      # only created when ALL referenced tables are available (all_ready); when
      # some are still missing we fall back to the primary table until everything
      # is imported.

      needs_view = all_ready &&
        (imported.size > 1 || CartodbRakeHelpers.needs_view?(layer.query))

      source = if needs_view && layer.query.present?
        view_name = "v_layer_#{layer.id}"

        # Schema-qualify all FROM/JOIN table references in the cleaned query
        view_sql = CartodbRakeHelpers.qualify_table_names_in_sql(
          layer.query, target_schema, imported
        )

        # update_layer_references stripped the_geom via strip_cartodb_columns.
        # For a wildcard SELECT (*) the geometry column comes through anyway;
        # for explicit column lists we must add it back so Martin can generate
        # vector tiles.  Use the alias of the primary table when one is present.
        unless view_sql.match?(/SELECT\s+\*/i) || view_sql.match?(/\bthe_geom\b|\bgeom\b/i)
          alias_match = layer.query.match(
            /\b(?:FROM|JOIN)\s+#{Regexp.escape(primary_table)}\s+(?:AS\s+)?(\w+)\b/i
          )
          geom_ref = alias_match ? "#{alias_match[1]}.the_geom"
                                 : "#{target_schema}.#{primary_table}.the_geom"
          view_sql = view_sql.sub(/\bSELECT\s+/i, "SELECT #{geom_ref}, ")
        end

        create_ddl = "CREATE OR REPLACE VIEW " \
                     "#{target_schema}.#{view_name} AS #{view_sql}"

        puts "  View     : #{target_schema}.#{view_name}"
        puts "  SQL      : #{view_sql}"

        if dry_run
          view_name
        else
          begin
            ar_conn.execute(create_ddl)
            puts "  ✓ View created."
            view_count += 1
            view_name
          rescue => e
            warn "  ✗ View creation failed: #{e.message}"
            warn "    Falling back to direct table reference."
            primary_table
          end
        end
      else
        # Could not create a view — either simple single-table select, or
        # some tables are still missing.  For the latter case, print the SQL
        # and stash it in the migration block so it is not lost when we retry.
        if !all_ready && layer.query.present? &&
            (imported.size > 1 || CartodbRakeHelpers.needs_view?(layer.query))
          puts "  ⚠  Cannot create view yet (missing tables). Original SQL:"
          puts "     #{layer.query}"
          migration = migration.merge("pending_view_sql" => layer.query)
        end

        primary_table
      end

      puts "  Source   : #{source}"
      puts "  Missing  : #{missing.join(", ")}" if missing.any?
      puts "  Publish  : #{all_ready ? "yes" : "no (missing tables)"}"

      # Translate CartoDB CSS to OL PathOptions for the styles block
      raw_styles = CartodbRakeHelpers.translate_vector_css(layer.css)
      default_styles = raw_styles.present? ? {source => raw_styles} : {}
      puts "  Styles   : #{raw_styles.present? ? "translated from CSS" : "none (no CSS)"}"

      # Build interaction_config from PostGIS table columns.
      # The OL frontend reads feature properties directly from the vector tile on click,
      # so no config.url is needed — just the output field list.
      table_for_ic = source.sub(/\Av_layer_\d+\z/, primary_table)
      martin_ic = CartodbRakeHelpers.build_martin_interaction_config(
        table_for_ic, ar_conn, target_schema
      )
      puts "  Interact : #{martin_ic ? "#{martin_ic["output"].size} columns" : "none"}"

      new_config = {
        "body" => {
          "source" => source,
          "styles" => default_styles,
          "options" => {"interactive" => true, "maxNativeZoom" => 14}
        },
        "cartodb_migration" => migration
      }

      unless dry_run
        update_attrs = {
          layer_provider: "martin",
          layer_config: new_config.to_json,
          published: all_ready
        }
        update_attrs[:interaction_config] = martin_ic.to_json if martin_ic
        layer.update_columns(**update_attrs)
      end

      configured_count += 1
      published_count += 1 if all_ready
    end

    puts "\n#{"=" * 56}"
    puts "  Martin Configuration#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Configured : #{configured_count}"
    puts "    Published   : #{published_count}"
    puts "    Unpublished : #{configured_count - published_count} (missing tables)"
    puts "  Skipped    : #{skipped_count}"
    puts "  Views created: #{view_count}" unless dry_run

    if configured_count - published_count > 0
      puts "\n  To pick up layers with missing tables:"
      puts "  Re-run import_tables → update_layer_references → configure_martin_layers"
    end
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Fix Martin source IDs in existing layer_configs.

    Martin auto-discovers PostgreSQL tables and registers them by bare table name
    (e.g. "grp_africa_livelihoods"), NOT by schema-qualified name
    ("ra_vector.grp_africa_livelihoods").  If configure_martin_layers was run
    before this fix was applied, the layer_config body.source values will have
    an incorrect "ra_vector." prefix, causing all tile requests to 404.

    This task strips the prefix from every affected layer and is safe to re-run.

    Usage:
      rake cartodb:fix_martin_sources
      rake cartodb:fix_martin_sources DRY_RUN=1
  DESC
  task fix_martin_sources: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    fixed = 0
    skipped = 0

    Layer.where(layer_provider: "martin")
      .where("layer_config LIKE '%cartodb_migration%'").find_each do |layer|
      config = begin
        JSON.parse(layer.layer_config)
      rescue
        {}
      end
      source = config.dig("body", "source").to_s

      unless source.start_with?("ra_vector.")
        skipped += 1
        next
      end

      bare_source = source.sub(/\Ara_vector\./, "")
      puts "Layer ##{layer.id}: #{source} → #{bare_source}"

      unless dry_run
        config["body"]["source"] = bare_source
        layer.update_column(:layer_config, config.to_json)
      end

      fixed += 1
    end

    puts "\n#{"=" * 56}"
    puts "  fix_martin_sources#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Fixed   : #{fixed}"
    puts "  Skipped : #{skipped} (already correct)"
    puts "\nRestart Martin if any sources were fixed: docker service update --force <stack>_martin" if fixed > 0 && !dry_run
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Populate missing styles in martin layer configs by translating CartoDB CSS.

    Layers migrated before CSS translation was added have an empty `styles: {}`
    in their layer_config, which causes the OpenLayers plugin to render nothing.
    This task reads the original CartoDB CSS from each layer and converts it to
    OL PathOptions format (color, weight, fillColor, fillOpacity, conditions).

    Layers that already have a non-empty styles object are left unchanged.

    Optional:
      DRY_RUN=1   Print what would change without saving

    Usage:
      rake cartodb:fix_martin_styles
      rake cartodb:fix_martin_styles DRY_RUN=1
  DESC
  task fix_martin_styles: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    updated = 0
    skipped = 0
    no_css = 0

    Layer.where(layer_provider: "martin")
      .where("layer_config LIKE '%cartodb_migration%'").find_each do |layer|
      config = begin
        JSON.parse(layer.layer_config)
      rescue
        {}
      end
      source = config.dig("body", "source").to_s
      styles = config.dig("body", "styles")

      if styles.present? && styles != {}
        skipped += 1
        next
      end

      if layer.css.blank?
        puts "Layer ##{layer.id} (#{layer.slug}): no CSS — skipping"
        no_css += 1
        next
      end

      translated = CartodbRakeHelpers.translate_vector_css(layer.css)
      if translated.blank?
        puts "Layer ##{layer.id} (#{layer.slug}): CSS yielded no usable styles — skipping"
        no_css += 1
        next
      end

      new_styles = source.present? ? {source => translated} : translated
      puts "Layer ##{layer.id} (#{layer.slug}): #{new_styles.to_json}"

      unless dry_run
        config["body"]["styles"] = new_styles
        layer.update_column(:layer_config, config.to_json)
      end

      updated += 1
    end

    puts "\n#{"=" * 56}"
    puts "  fix_martin_styles#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Updated : #{updated}"
    puts "  Skipped : #{skipped} (already have styles)"
    puts "  No CSS  : #{no_css} (no CSS or unrecognised CSS)"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Re-translate CartoDB raster CSS into TiTiler colormap/rescale for all COG layers.

    Runs translate_raster_css against every COG layer's original CSS and
    overwrites body.colormap, body.rescale, and body.cartocss_mode.  The CSS is
    the authoritative source; any previously stored colormap is replaced.

    Layers with no CSS and no existing colormap are reported as skipped.

    Correctly handles all CartoDB coloriser modes:
      linear   — gradient dict colormap {"key": [r,g,b,a]} with rescale
      discrete — interval array [[[lower,upper],[r,g,b,a]],...] without rescale
      exact    — interval array spanning one unit per stop, without rescale

    Optional:
      DRY_RUN=1   Print what would change without saving

    Usage:
      rake cartodb:fix_cog_styles
      rake cartodb:fix_cog_styles DRY_RUN=1
  DESC
  task fix_cog_styles: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    updated = 0
    skipped = 0
    no_css = 0

    Layer.where(layer_provider: "cog").find_each do |layer|
      config = begin
        JSON.parse(layer.layer_config)
      rescue
        {}
      end
      if layer.css.blank?
        existing_colormap = config.dig("body", "colormap")
        if existing_colormap.present?
          skipped += 1  # no CSS but already has a colormap — leave it alone
        else
          puts "Layer ##{layer.id} (#{layer.slug}): no CSS and no colormap — skipping"
          no_css += 1
        end
        next
      end

      style = CartodbRakeHelpers.translate_raster_css(layer.css)

      if style["colormap"].blank?
        puts "Layer ##{layer.id} (#{layer.slug}): CSS yielded no colormap — skipping"
        no_css += 1
        next
      end

      puts "Layer ##{layer.id} (#{layer.slug}): #{style["colormap"].size} colormap entries, rescale=#{style["rescale"]}"

      unless dry_run
        config["body"]["colormap"] = style["colormap"]
        # Interval colormaps (discrete/exact) don't use rescale; remove any
        # stale rescale value left from a previous linear-mode migration.
        if style["rescale"].present?
          config["body"]["rescale"] = style["rescale"]
        else
          config["body"].delete("rescale")
        end
        config["body"]["cartocss_mode"] = style["mode"] if style["mode"].present?
        # Persist the translated style into cartodb_migration so re-runs are stable
        config["cartodb_migration"] ||= {}
        config["cartodb_migration"]["style"] = style
        layer.update_column(:layer_config, config.to_json)
      end

      updated += 1
    end

    puts "\n#{"=" * 56}"
    puts "  fix_cog_styles#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Updated : #{updated}"
    puts "  Skipped : #{skipped} (no CSS, no existing colormap)"
    puts "  No CSS  : #{no_css} (CSS present but yielded no colormap)"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Ensure every COG layer has the correct body.sources array for multi-table layers.

    For layers whose original CartoDB SQL used UNION across multiple raster tables
    (e.g. SELECT … FROM table_a UNION SELECT … FROM table_b), each table becomes
    an independent COG on S3.  The frontend renders them as a geographic mosaic via
    a separate TiTiler /cog/tiles/ request per source.

    This task re-derives the raster table list from source_sql stored in
    cartodb_migration, excludes any tables that exist locally in the vector schema
    (vector boundary tables used with ST_CLIP), and rebuilds body.source /
    body.sources accordingly.

    Run after every bulk migration and whenever COG sources may be incomplete.

    Options:
      S3_BUCKET=<name>              S3 bucket (default: resilienceatlas)
      COG_PREFIX=<prefix>           S3 key prefix  (default: cogs/)
      CARTODB_IMPORT_SCHEMA=<name>  Vector schema   (default: ra_vector)
      DRY_RUN=1                     Print changes without writing

    Usage:
      rake cartodb:fix_cog_sources
      rake cartodb:fix_cog_sources DRY_RUN=1
  DESC
  task fix_cog_sources: :environment do
    s3_bucket     = ENV.fetch("S3_BUCKET", "resilienceatlas")
    cog_prefix    = ENV.fetch("COG_PREFIX", "cogs/")
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    dry_run       = ENV["DRY_RUN"] == "1"

    ar_conn = ActiveRecord::Base.connection

    updated = 0
    skipped = 0
    no_sql  = 0

    Layer.where(layer_provider: "cog").find_each do |layer|
      config    = begin JSON.parse(layer.layer_config) rescue {} end
      migration = config["cartodb_migration"] || {}
      source_sql = migration["source_sql"].to_s.strip

      if source_sql.blank?
        no_sql += 1
        next
      end

      referenced = CartodbRakeHelpers.extract_table_names_from_sql(source_sql)

      if referenced.empty?
        no_sql += 1
        next
      end

      # Tables that exist locally in the vector schema are boundary/clip helpers,
      # not raster tiles — exclude them from the COG source list.
      local_vector = referenced.select { |t| ar_conn.table_exists?("#{target_schema}.#{t}") }
      raster_tables = referenced - local_vector

      if raster_tables.empty?
        puts "Layer ##{layer.id} (#{layer.slug}): no raster tables found — skipping"
        no_sql += 1
        next
      end

      sources = raster_tables.map { |t| CartodbRakeHelpers.build_cog_source_url(s3_bucket, cog_prefix, t) }

      current_sources = (
        Array(config.dig("body", "sources")).presence ||
        [config.dig("body", "source")].compact
      )

      if current_sources.sort == sources.sort
        skipped += 1
        next
      end

      puts "Layer ##{layer.id} (#{layer.slug}): #{raster_tables.size} raster table(s)"
      puts "  Was: #{current_sources.join(", ")}"
      puts "  Now: #{sources.join(", ")}"

      unless dry_run
        config["body"]["source"]  = sources.first
        config["body"]["sources"] = sources
        migration["raster_tables"] = raster_tables
        config["cartodb_migration"] = migration

        # Also refresh clip geometry whenever sources are updated
        if source_sql.match?(/\bst_clip\s*\(/i)
          clip_geom = CartodbRakeHelpers.extract_clip_geometry(
            source_sql, ar_conn, target_schema
          )
          if clip_geom
            config["body"]["clip_geometry"] = clip_geom
            puts "  Clip     : #{clip_geom.dig("geometry", "type")} refreshed"
          else
            config["body"].delete("clip_geometry")
          end
        end

        layer.update_column(:layer_config, config.to_json)
      end

      updated += 1
    end

    puts "\n#{"=" * 56}"
    puts "  fix_cog_sources#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Updated : #{updated}"
    puts "  Skipped : #{skipped} (sources already correct)"
    puts "  No SQL  : #{no_sql} (no source SQL found)"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Backfill clip geometry for COG layers that use ST_CLIP boundary tables.

    For layers whose original CartoDB SQL clipped the raster to a vector boundary
    (e.g. WITH geom AS (SELECT ... FROM country_boundary)), this task extracts
    the boundary polygon from the ra_vector schema, simplifies it, and stores
    it as body.clip_geometry in the layer_config.

    The frontend passes clip_geometry to TiTiler as the `feature` query parameter,
    which clips the rendered tile to the boundary shape.

    Safe to re-run — only layers with ST_CLIP SQL and an available boundary table
    are updated; layers without ST_CLIP are untouched.

    Options:
      CARTODB_IMPORT_SCHEMA=<name>  Vector schema (default: ra_vector)
      DRY_RUN=1                     Print changes without writing

    Usage:
      rake cartodb:fix_cog_clip
      rake cartodb:fix_cog_clip DRY_RUN=1
  DESC
  task fix_cog_clip: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    dry_run       = ENV["DRY_RUN"] == "1"
    ar_conn       = ActiveRecord::Base.connection

    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    updated = 0
    skipped = 0
    no_clip = 0

    Layer.where(layer_provider: "cog").find_each do |layer|
      config    = begin JSON.parse(layer.layer_config) rescue {} end
      migration = config["cartodb_migration"] || {}
      source_sql = migration["source_sql"].to_s.strip

      unless source_sql.match?(/\bst_clip\s*\(/i)
        no_clip += 1
        next
      end

      clip_geom = CartodbRakeHelpers.extract_clip_geometry(source_sql, ar_conn, target_schema)

      unless clip_geom
        puts "Layer ##{layer.id} (#{layer.slug}): ST_CLIP detected but boundary unavailable"
        skipped += 1
        next
      end

      current = config.dig("body", "clip_geometry")
      if current == clip_geom
        skipped += 1
        next
      end

      table = CartodbRakeHelpers.extract_clip_info(source_sql)&.dig(:table)
      puts "Layer ##{layer.id} (#{layer.slug}): clip from #{table} → #{clip_geom.dig("geometry", "type")}"

      unless dry_run
        config["body"]["clip_geometry"] = clip_geom
        layer.update_column(:layer_config, config.to_json)
      end

      updated += 1
    end

    puts "\n#{"=" * 56}"
    puts "  fix_cog_clip#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Updated : #{updated}"
    puts "  Skipped : #{skipped} (no change or boundary unavailable)"
    puts "  No CLIP : #{no_clip} (no ST_CLIP in source SQL)"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Build interaction_config for all Martin layers from their PostGIS table columns.

    For each Martin layer, queries the ra_vector schema table to discover its
    data columns and stores them as interaction_config.output.  This enables
    the OpenLayers frontend to show a click popup with feature attribute values
    without any HTTP round-trip — OL reads properties directly from the vector tile.

    Layers that already have a non-empty interaction_config are left unchanged.
    Use FORCE=1 to overwrite existing configs.

    Options:
      CARTODB_IMPORT_SCHEMA=<name>  Vector schema (default: ra_vector)
      FORCE=1                       Overwrite existing interaction_config
      DRY_RUN=1                     Print changes without writing

    Usage:
      rake cartodb:fix_martin_interactivity
      rake cartodb:fix_martin_interactivity FORCE=1
  DESC
  task fix_martin_interactivity: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    dry_run       = ENV["DRY_RUN"] == "1"
    force         = ENV["FORCE"] == "1"
    ar_conn       = ActiveRecord::Base.connection

    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    updated = 0
    skipped = 0
    no_table = 0

    Layer.where(layer_provider: "martin")
      .where("layer_config LIKE '%cartodb_migration%'").find_each do |layer|
      if !force && layer.interaction_config.present? &&
          layer.interaction_config != '{"output":[]}' &&
          layer.interaction_config != '{"output": []}'
        skipped += 1
        next
      end

      config = begin JSON.parse(layer.layer_config) rescue {} end
      source = config.dig("body", "source").to_s.sub(/\Ara_vector\./, "")

      if source.blank?
        no_table += 1
        next
      end

      ic = CartodbRakeHelpers.build_martin_interaction_config(source, ar_conn, target_schema)

      unless ic
        puts "Layer ##{layer.id} (#{layer.slug}): no data columns in #{source}"
        no_table += 1
        next
      end

      puts "Layer ##{layer.id} (#{layer.slug}): #{ic["output"].size} columns from #{source}"

      unless dry_run
        layer.update_column(:interaction_config, ic.to_json)
      end

      updated += 1
    end

    puts "\n#{"=" * 56}"
    puts "  fix_martin_interactivity#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Updated  : #{updated}"
    puts "  Skipped  : #{skipped} (already has interaction_config; use FORCE=1 to overwrite)"
    puts "  No table : #{no_table} (source table not found or no data columns)"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Set interaction_config for all migrated COG layers to use TiTiler point query.

    For each COG layer without an interaction_config, sets the standard TiTiler
    /cog/point endpoint config so that map clicks return the raster pixel value.

    Layers that already have a non-empty interaction_config are left unchanged.
    Use FORCE=1 to overwrite existing configs.

    Options:
      FORCE=1    Overwrite existing interaction_config
      DRY_RUN=1  Print changes without writing

    Usage:
      rake cartodb:fix_cog_interactivity
      rake cartodb:fix_cog_interactivity FORCE=1
  DESC
  task fix_cog_interactivity: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    force   = ENV["FORCE"] == "1"

    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    updated = 0
    skipped = 0

    ic = CartodbRakeHelpers.build_cog_interaction_config

    Layer.where(layer_provider: "cog").find_each do |layer|
      if !force && layer.interaction_config.present? &&
          layer.interaction_config != '{"output":[]}' &&
          layer.interaction_config != '{"output": []}'
        skipped += 1
        next
      end

      puts "Layer ##{layer.id} (#{layer.slug})"

      unless dry_run
        layer.update_column(:interaction_config, ic.to_json)
      end

      updated += 1
    end

    puts "\n#{"=" * 56}"
    puts "  fix_cog_interactivity#{dry_run ? " (DRY RUN)" : ""} — Summary"
    puts "=" * 56
    puts "  Updated : #{updated}"
    puts "  Skipped : #{skipped} (already has interaction_config; use FORCE=1 to overwrite)"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Full CartoDB migration pipeline — import, configure, and repair in one command.

    Steps (run in order):
       1. import_tables             — download and import .gpkg / .csv.gz files from S3
       2. update_layer_references   — parse SQL, classify raster vs vector, strip CartoDB columns
       3. configure_cog_layers      — set provider=cog, build COG sources, translate CSS colormaps
       4. configure_martin_layers   — set provider=martin, build Martin sources, translate CSS styles
       5. fix_cog_styles            — re-translate colormaps for all existing COG layers
       6. fix_cog_sources           — rebuild body.sources for multi-table COG mosaic layers
       7. fix_cog_clip              — store clip boundary geometry for ST_CLIP layers
       8. fix_cog_interactivity     — set TiTiler point-query interaction_config for COG layers
       9. fix_martin_sources        — strip ra_vector. prefix from Martin source IDs
      10. fix_martin_styles         — backfill missing PathOptions styles for Martin layers
      11. fix_martin_interactivity  — build click popup field list from PostGIS table columns

    Steps 5-11 are idempotent repairs that ensure all layers in the database are
    correct, not just the ones configured in this run.  This means migrate_tables
    is safe to re-run at any time — no separate fix_* tasks are needed.

    Accepts all environment variables from the sub-tasks:
      CARTODB_S3_BUCKET, CARTODB_VECTORS_S3_PREFIX, CARTODB_TABLES_S3_PREFIX,
      CARTODB_EXPORT_DIR, CARTODB_IMPORT_SCHEMA, S3_BUCKET, COG_PREFIX, FORCE

    Usage:
      rake cartodb:migrate_tables CARTODB_S3_BUCKET=resilienceatlas
      rake cartodb:migrate_tables CARTODB_S3_BUCKET=resilienceatlas FORCE=1
  DESC
  task migrate_tables: [
    "cartodb:import_tables",
    "cartodb:update_layer_references",
    "cartodb:configure_cog_layers",
    "cartodb:configure_martin_layers",
    "cartodb:fix_cog_styles",
    "cartodb:fix_cog_sources",
    "cartodb:fix_cog_clip",
    "cartodb:fix_cog_interactivity",
    "cartodb:fix_martin_sources",
    "cartodb:fix_martin_styles",
    "cartodb:fix_martin_interactivity"
  ]

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Create GiST spatial indices on all geometry columns in the ra_vector schema.

    Run this once after a bulk import to ensure Martin can compute tile bounds
    quickly at startup (without indices Martin times out and drops all sources).
    New imports via cartodb:import_tables create indices automatically; this task
    is for tables that were imported before that step was added.

    Optional:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema to index (default: ra_vector)

    Usage:
      rake cartodb:create_spatial_indices
  DESC
  task create_spatial_indices: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    ar_conn = ActiveRecord::Base.connection

    rows = ar_conn.execute(
      "SELECT f_table_name, f_geometry_column " \
      "FROM geometry_columns " \
      "WHERE f_table_schema = '#{target_schema}' " \
      "ORDER BY f_table_name, f_geometry_column"
    ).to_a

    if rows.empty?
      puts "No geometry columns found in schema '#{target_schema}'.  Nothing to do."
      next
    end

    puts "Creating GiST spatial indices for #{rows.size} geometry column(s) in #{target_schema}...\n\n"

    created = 0
    skipped = 0
    failed = 0

    rows.each_with_index do |row, i|
      tbl = row["f_table_name"]
      col = row["f_geometry_column"]
      idx_name = "idx_#{tbl}_#{col}"[0, 63]
      q_table = "\"#{target_schema}\".\"#{tbl}\""

      print "  [#{i + 1}/#{rows.size}] #{tbl}.#{col} → #{idx_name} ... "

      # Check if the index already exists to give an accurate created/skipped count.
      exists = ar_conn.execute(
        "SELECT 1 FROM pg_indexes " \
        "WHERE schemaname = '#{target_schema}' AND indexname = '#{idx_name}'"
      ).any?

      if exists
        puts "already exists."
        skipped += 1
        next
      end

      begin
        ar_conn.execute(
          "CREATE INDEX \"#{idx_name}\" ON #{q_table} USING gist(\"#{col}\")"
        )
        puts "done."
        created += 1
      rescue => e
        warn "FAILED: #{e.message}"
        failed += 1
      end
    end

    puts "\n#{"=" * 50}"
    puts "  Created : #{created}"
    puts "  Skipped : #{skipped} (already existed)"
    puts "  Failed  : #{failed}"
    puts ""
    puts "Restart Martin to pick up the new indices:"
    puts "  docker service update --force resilienceatlas-staging_martin"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Repair invalid geometries in all tables in the ra_vector schema using ST_MakeValid.

    Invalid or corrupt geometries crash the PostGIS backend process when Martin
    runs ST_CurveToLine / ST_Transform / ST_AsMVTGeom, causing "connection closed"
    tile errors.  New imports via cartodb:import_tables repair geometries
    automatically; this task is for tables that were imported before that step
    was added.

    Optional:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema to repair (default: ra_vector)

    Usage:
      rake cartodb:fix_invalid_geometries
  DESC
  task fix_invalid_geometries: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    ar_conn = ActiveRecord::Base.connection

    rows = ar_conn.execute(
      "SELECT f_table_name, f_geometry_column " \
      "FROM geometry_columns " \
      "WHERE f_table_schema = '#{target_schema}' " \
      "ORDER BY f_table_name, f_geometry_column"
    ).to_a

    if rows.empty?
      puts "No geometry columns found in schema '#{target_schema}'.  Nothing to do."
      next
    end

    puts "Checking #{rows.size} geometry column(s) in #{target_schema} for invalid geometries...\n\n"

    tables_fixed = 0
    total_fixed = 0
    failed = 0

    rows.each_with_index do |row, i|
      tbl = row["f_table_name"]
      col = row["f_geometry_column"]
      q_table = "\"#{target_schema}\".\"#{tbl}\""

      begin
        # Fast path: count then repair all at once (works for most tables)
        invalid_count = ar_conn.execute(
          "SELECT count(*) FROM #{q_table} WHERE NOT ST_IsValid(\"#{col}\")"
        ).first["count"].to_i

        if invalid_count > 0
          print "  [#{i + 1}/#{rows.size}] #{tbl}.#{col}: #{invalid_count} invalid — repairing... "
          ar_conn.execute(
            "UPDATE #{q_table} SET \"#{col}\" = ST_MakeValid(\"#{col}\") " \
            "WHERE NOT ST_IsValid(\"#{col}\")"
          )
          puts "done."
          tables_fixed += 1
          total_fixed += invalid_count
        end
      rescue => e
        # Fast path failed (likely OOM on a huge table). Reconnect then retry
        # using ctid-batched updates so each transaction is small.
        warn "  [#{i + 1}/#{rows.size}] #{tbl}.#{col}: full-table repair failed " \
             "(#{e.message.lines.first.strip}) — retrying in batches..."
        begin
          ActiveRecord::Base.connection_pool.disconnect!
          ar_conn = ActiveRecord::Base.connection
        rescue => re
          warn "  WARNING: Reconnect failed: #{re.message.lines.first.strip}"
          failed += 1
          next
        end

        col_fixed = 0
        batch_failed = false
        loop do
          n = ar_conn.execute(
            "WITH batch AS ( " \
            "  SELECT ctid FROM #{q_table} " \
            "  WHERE NOT ST_IsValid(\"#{col}\") LIMIT 500 " \
            ") " \
            "UPDATE #{q_table} t " \
            "SET \"#{col}\" = ST_MakeValid(t.\"#{col}\") " \
            "FROM batch WHERE t.ctid = batch.ctid"
          ).cmd_tuples
          col_fixed += n
          break if n == 0
        rescue => be
          warn "  [#{i + 1}/#{rows.size}] #{tbl}.#{col}: batched retry also failed — " \
               "#{be.message.lines.first.strip}"
          batch_failed = true
          begin
            ActiveRecord::Base.connection_pool.disconnect!
            ar_conn = ActiveRecord::Base.connection
          rescue; end
          break
        end

        if batch_failed
          failed += 1
        elsif col_fixed > 0
          puts "  [#{i + 1}/#{rows.size}] #{tbl}.#{col}: fixed #{col_fixed} invalid geometry(ies) via batches."
          tables_fixed += 1
          total_fixed += col_fixed
        end
      end
    end

    puts "\n#{"=" * 50}"
    puts "  Tables repaired : #{tables_fixed}"
    puts "  Geometries fixed: #{total_fixed}"
    puts "  Failed          : #{failed}"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Show the current migration status of formerly CartoDB layers and their referenced tables.

    Optional:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema to check for imported tables (default: public)

    Usage:
      rake cartodb:status
  DESC
  task status: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "public")
    ar_conn = ActiveRecord::Base.connection

    # Mirror the same broad filter used by update_layer_references so the
    # status report accurately reflects how many layers will be processed.
    formerly_cartodb = Layer
      .where(layer_provider: nil, published: false)
      .where(
        "NOT (query IS NULL OR query = '') OR " \
        "layer_config LIKE '%cartodb_migration%' OR " \
        "(layer_config LIKE '%\"body\"%' AND layer_config LIKE '%\"sql\"%')"
      )
      .order(:id)

    # Layers that are still completely unreachable (no query, no CartoDB config)
    no_sql_count = Layer
      .where(layer_provider: nil, published: false)
      .where(
        "(query IS NULL OR query = '') AND " \
        "(layer_config NOT LIKE '%cartodb_migration%' OR layer_config IS NULL) AND " \
        "NOT (layer_config LIKE '%\"body\"%' AND layer_config LIKE '%\"sql\"%')"
      ).count

    total_null = Layer.where(layer_provider: nil).count

    puts "=== CartoDB Migration Status (#{Time.current.strftime("%Y-%m-%d %H:%M")}) ==="
    puts ""
    puts "  Layers with provider=NULL                    : #{total_null}"
    puts "  of which processable by update_layer_references: #{formerly_cartodb.count}"
    puts "  of which unreachable (no SQL anywhere)         : #{no_sql_count}" if no_sql_count > 0
    puts ""

    if formerly_cartodb.empty?
      puts "No formerly CartoDB layers remain.  Migration appears complete."
      next
    end

    all_ready = 0
    partial = 0
    pending = 0

    formerly_cartodb.each do |layer|
      source_sql = layer.query.presence ||
        CartodbRakeHelpers.extract_sql_from_cartodb_config(layer.layer_config)
      referenced = CartodbRakeHelpers.extract_table_names_from_sql(source_sql)
      next if referenced.empty?

      statuses = referenced.map do |t|
        [t, ar_conn.table_exists?("#{target_schema}.#{t}") ? :available : :missing]
      end.to_h

      all_avail = statuses.values.all? { |s| s == :available }
      any_avail = statuses.values.any? { |s| s == :available }

      icon = if all_avail
        "✓"
      else
        (any_avail ? "~" : "✗")
      end

      if all_avail
        all_ready += 1
      elsif any_avail
        partial += 1
      else
        pending += 1
      end

      puts "  #{icon} ##{layer.id} #{layer.slug}"
      statuses.each do |t, s|
        puts "      #{(s == :available) ? "✓" : "✗"} #{target_schema}.#{t}  (#{s})"
      end
    end

    puts ""
    puts "  All tables imported : #{all_ready}"
    puts "  Partial             : #{partial}"
    puts "  No tables yet       : #{pending}"
    puts ""
    puts "Run `rake cartodb:migrate_tables` to import tables and update layer references."
  end
end
