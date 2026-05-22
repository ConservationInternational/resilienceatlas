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

  # Extract the band number that CartoDB was rendering for a raster SQL query.
  #
  # CartoDB's raster SQL uses ST_CLIP in one of two forms:
  #   ST_Clip(rast, band_num, geom, ...)  ← band is the 2nd integer argument
  #   ST_Clip(rast, geom, ...)            ← no explicit band (renders band 1)
  #
  # When a band number is present it is always 1 across the entire dataset, but
  # parsing it from the SQL gives an explicit, verified value rather than a
  # silent assumption.  Returns 1 when no explicit band is found.
  def self.extract_raster_band_from_sql(sql)
    return 1 if sql.blank?

    # Match: ST_CLIP( <raster_column> , <integer> , ...
    # The raster column is a simple identifier (word chars / dots / quotes).
    if (m = sql.match(/\bst_clip\s*\(\s*[\w."]+\s*,\s*(\d+)\s*,/i))
      return m[1].to_i
    end

    # No explicit band specified → CartoDB rendered band 1 by default.
    1
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
  def self.build_titiler_colormap(stops, mode: "linear", default_rgba: nil)
    return nil if stops.blank?

    if %w[discrete exact].include?(mode.to_s.downcase)
      build_interval_colormap(stops, exact: mode.to_s.downcase == "exact", default_rgba: default_rgba)
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
  #
  # When default_rgba is given (e.g. [0,0,0,0] for transparent), a sentinel
  # interval is prepended covering [-32768, first_stop) so that out-of-range
  # pixel values (e.g. nodata=0) receive the CartoDB default colour rather
  # than TiTiler's own fallback (opaque black).
  def self.build_interval_colormap(stops, exact: false, default_rgba: nil)
    sorted = stops.sort_by { |s| s[:value] }
    colormap = []

    # Prepend sentinel for values below the minimum stop.
    if default_rgba && sorted.any?
      colormap << [[-32768, sorted.first[:value]], default_rgba]
    end

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

    # raster-colorizer-default-color: the colour TiTiler should use for pixel
    # values that fall outside all defined stop intervals.  Most CartoDB layers
    # use "transparent" here, so we propagate that as a sentinel interval.
    raw_default_color = css[/raster-colorizer-default-color\s*:\s*(rgba?\([^;\}]+\)|transparent|#transparent|#[0-9a-fA-F]+)/i, 1]&.strip
    default_rgba = raw_default_color.present? ? parse_hex_color(raw_default_color) : nil

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

      # For linear (gradient) mode: if the lowest or highest stop is transparent
      # it is a nodata sentinel, not a real gradient endpoint.  Keeping it inflates
      # the min/max range used for rescale — e.g. stop(20000,transparent) forces
      # rescale="0,20000", compressing real data values (1–17) into keys 0–6 of
      # the 0-255 gradient space so they all appear transparent.  Override to
      # interval/discrete mode only when this compression would actually occur.
      # When transparent stops are at or near the data boundaries (e.g. a
      # temperature layer spanning -2..2.1 with transparent sentinels at those
      # same values), the gradient colormap works correctly — values below/above
      # the rescale range clamp to the transparent endpoint keys automatically.
      effective_mode = mode || "linear"
      if effective_mode == "linear"
        sorted_stops = stops.sort_by { |s| s[:value] }
        terminal_transparent =
          parse_hex_color(sorted_stops.first[:color]) == [0, 0, 0, 0] ||
          parse_hex_color(sorted_stops.last[:color]) == [0, 0, 0, 0]
        if terminal_transparent
          colored_stops = sorted_stops.reject { |s| parse_hex_color(s[:color]) == [0, 0, 0, 0] }
          if colored_stops.empty?
            effective_mode = "discrete"
          else
            total_range = sorted_stops.last[:value].to_f - sorted_stops.first[:value].to_f
            colored_range = colored_stops.last[:value].to_f - colored_stops.first[:value].to_f
            # Only switch to discrete when the colored range covers less than half
            # of the total stop range — indicating a far-outlier nodata sentinel.
            effective_mode = "discrete" if total_range > 0 && colored_range / total_range < 0.5
          end
        end
      end

      result["colormap"] = build_titiler_colormap(stops, mode: effective_mode, default_rgba: default_rgba)
      # Gradient colormaps (linear mode) require rescale to normalise pixel
      # values into the 0-255 key space.  Interval colormaps (discrete/exact)
      # use raw pixel values directly, so rescale must NOT be set.
      unless %w[discrete exact].include?(effective_mode)
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

  # Detect the first real layer name inside a GeoPackage.
  # CartoDB exports are generated via ogr2ogr -sql, so the layer is usually
  # named "sql_statement" rather than the original table name.
  def self.detect_gpkg_layer_name(path)
    require "shellwords"

    output = `ogrinfo -ro -so #{Shellwords.escape(path.to_s)} 2>/dev/null`
    return nil unless $CHILD_STATUS.success?

    output.each_line do |line|
      match = line.match(/^\s*\d+\s*:\s*(.+?)(?:\s+\(|\s*$)/)
      next unless match

      layer_name = match[1].to_s.strip
      next if layer_name.blank?
      next if layer_name.start_with?("gpkg_", "sqlite_")

      return layer_name
    end

    nil
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

  # Sample up to +limit+ rows from a CSV or gzipped CSV file and infer a
  # PostgreSQL column type for each column.  Falls back to TEXT for anything
  # that does not look like a plain integer, decimal, or boolean.
  # Supports both plain .csv and .csv.gz files.
  def self.infer_column_types_from_file(file_path, limit: 1_000)
    require "csv"
    require "zlib"

    col_samples = {}

    opener = if file_path.to_s.end_with?(".gz")
      ->(p, &b) { Zlib::GzipReader.open(p, &b) }
    else
      ->(p, &b) { File.open(p, encoding: "UTF-8", &b) }
    end

    opener.call(file_path) do |io|
      csv = CSV.new(io, headers: true)
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

  # Convenience alias for gzip-compressed CSV files (backwards-compatible).
  def self.infer_column_types(gz_path, limit: 1_000)
    infer_column_types_from_file(gz_path, limit: limit)
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

  # Fix missing whitespace before SQL clause-starting keywords.
  # CartoDB SQL stored in the database sometimes has collapsed newlines that
  # removed the space between a clause-ending token and the next keyword,
  # producing tokens like `l.landscape_noWHERE` instead of `l.landscape_no WHERE`.
  # INSERT a single space before each affected keyword.
  #
  # Only keywords that unambiguously begin a new SQL clause are handled here;
  # `FROM`, `JOIN`, and `ON` are intentionally excluded because they can appear
  # as substrings of legitimate identifiers (e.g. `from_date`, `platform`).
  def self.fix_sql_keyword_spacing(sql)
    return sql if sql.blank?

    result = sql.dup
    %w[WHERE HAVING UNION EXCEPT INTERSECT].each do |kw|
      result = result.gsub(/(\w)(#{kw})\b/i) { "#{$1} #{$2}" }
    end
    result
  end

  # Fix "SELECT  FROM schema.table" patterns where strip_cartodb_columns has
  # removed the sole column (the_geom) from a subquery SELECT, leaving only
  # whitespace between SELECT and FROM.  Replaces the missing column with the
  # table's actual geometry column as reported by geometry_columns.
  def self.fix_empty_subquery_selects(sql, schema, ar_conn)
    return sql if sql.blank?

    sql.gsub(/\bSELECT(\s+)(FROM\s+(?:"?#{Regexp.escape(schema)}"?\.)?"?(\w+)"?\b)/i) do
      space = $1
      from_part = $2
      tbl = $3.downcase
      geom = begin
        ar_conn.execute(
          "SELECT f_geometry_column FROM geometry_columns " \
          "WHERE f_table_schema = #{ar_conn.quote(schema)} " \
          "AND f_table_name = #{ar_conn.quote(tbl)} LIMIT 1"
        ).first&.dig("f_geometry_column")
      rescue
        nil
      end
      geom ? "SELECT #{geom} #{from_part}" : "SELECT#{space}#{from_part}"
    end
  end

  # Schema-qualify unqualified table names in FROM/JOIN clauses using a per-table
  # schema map: { table_name => schema }.  Use this when tables from multiple
  # schemas (e.g. ra_vector + ra_nonspatial) appear in the same query.
  # Longest names are processed first to prevent partial-name clobbering.
  def self.qualify_table_names_in_sql_multi(sql, table_schema_map)
    return sql if sql.blank?

    qualified = sql.dup
    table_schema_map.sort_by { |t, _| -t.length }.each do |tbl, schema|
      escaped = Regexp.escape(tbl)
      qualified.gsub!(
        /\b(FROM|JOIN)\s+("?#{escaped}"?)(?=\s|,|\z|;)/i
      ) { "#{$1} #{schema}.#{$2}" }
    end
    qualified
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

  # Returns the geometry reference (e.g. "t2.the_geom") for the first table
  # among `table_names` that has a geometry column in PostGIS, using the alias
  # present in `sql`.  Falls back to "schema.table.the_geom" when unaliased.
  # Returns nil when none of the tables has a geometry column.
  #
  # Uses the unqualified `sql` for alias extraction so callers can pass the
  # original (pre-qualify) query and the schema-qualified view SQL interchangeably.
  SQL_KEYWORD_RE = /\A(?:where|on|inner|outer|left|right|full|cross|join|set|as|and|or|not|in|is|null|group|order|having|limit|offset|select|from|union|with|using|distinct)\z/i

  def self.find_geometry_column_ref(sql, schema, table_names, ar_conn)
    return nil if table_names.empty? || sql.blank?

    quoted = table_names.map { |t| "'#{ar_conn.quote_string(t)}'" }.join(", ")
    rows = ar_conn.execute(
      "SELECT f_table_name, f_geometry_column, srid FROM geometry_columns " \
      "WHERE f_table_schema = '#{schema}' AND f_table_name IN (#{quoted})"
    ).map { |r| [r["f_table_name"], r["f_geometry_column"], r["srid"].to_i] }

    return nil if rows.empty?

    # Sort candidates to prefer the table most likely to carry real geometry:
    # 1. Non-zero SRID and has at least one non-NULL geometry row  (best)
    # 2. Non-zero SRID but geometry column is entirely NULL        (possible)
    # 3. SRID=0 — ogr2ogr dummy column from a non-spatial import  (worst)
    # This prevents selecting a joined non-spatial table's dummy geom column
    # (e.g. dhs_indicators or poverty_gha_national_csv) over the real spatial
    # table (e.g. dhs_regions or country_mask) when both appear in geometry_columns.
    rows = rows.sort_by do |tbl, geom_col, srid|
      if srid.zero?
        2  # last: SRID=0 → likely a non-spatial import with a dummy geometry
      else
        has_data = ar_conn.execute(
          "SELECT 1 FROM \"#{schema}\".\"#{tbl}\" WHERE \"#{geom_col}\" IS NOT NULL LIMIT 1"
        ).ntuples > 0
        has_data ? 0 : 1
      end
    end

    rows.each do |tbl, geom_col, _srid|
      # Look for: FROM/JOIN [schema.]<tbl> [AS] alias  — alias is optional
      m = sql.match(/\b(?:FROM|JOIN)\s+(?:#{Regexp.escape(schema)}\.)?#{Regexp.escape(tbl)}\s+(?:AS\s+)?([a-zA-Z_]\w*)\b/i)
      if m && !m[1].match?(SQL_KEYWORD_RE)
        return "#{m[1]}.#{geom_col}"
      else
        return "#{schema}.#{tbl}.#{geom_col}"
      end
    end

    nil
  end

  # Inject `geom_ref` (e.g. "t2.geom") into the outermost SELECT clause
  # of `view_sql`.  Handles both plain queries and CTEs (WITH ... AS (...) SELECT).
  # For CTEs the injection point is the SELECT that follows the last CTE definition.
  def self.inject_geometry_into_select(view_sql, geom_ref)
    if view_sql.match?(/\bWITH\b/i)
      # CTE form: the outermost SELECT follows the closing ) of the last CTE.
      view_sql.sub(/(\)\s*\n?\s*)(SELECT\s+)/im, "\\1SELECT #{geom_ref}, ")
    else
      view_sql.sub(/\bSELECT\s+/i, "SELECT #{geom_ref}, ")
    end
  end

  # For UNION/UNION ALL queries: ensure every SELECT branch includes exactly
  # one geometry column.  Branches that already reference a known geometry
  # column are left unchanged; branches missing geometry get the appropriate
  # column injected from geometry_columns (or NULL::geometry when the branch's
  # table has no PostGIS geometry entry).
  #
  # This handles the common CartoDB pattern where `the_geom` appeared in only
  # the first UNION branch — after `the_geom` renaming, that branch has a real
  # geometry reference but subsequent branches are left without one, causing a
  # UNION column-count mismatch in PostgreSQL.
  #
  # Has no effect on non-UNION queries or CTEs (WITH ... SELECT).
  def self.balance_union_geometry(view_sql, schema, table_names, ar_conn)
    return view_sql unless view_sql.match?(/\bUNION\b/i) && !view_sql.match?(/\bWITH\b/i)
    return view_sql if table_names.empty?

    # Build geometry map: table_name → geometry_column_name
    quoted = table_names.map { |t| "'#{ar_conn.quote_string(t)}'" }.join(", ")
    geom_map = ar_conn.execute(
      "SELECT f_table_name, f_geometry_column FROM geometry_columns " \
      "WHERE f_table_schema = '#{schema}' AND f_table_name IN (#{quoted})"
    ).each_with_object({}) { |r, h| h[r["f_table_name"]] = r["f_geometry_column"] }

    return view_sql if geom_map.empty?

    geom_col_names = geom_map.values.uniq

    # Split on top-level UNION [ALL] keywords, respecting paren depth so that
    # UNIONs inside subqueries are not mistakenly split on.
    parts = []
    seps = []
    buf = +""
    depth = 0
    pos = 0

    while pos < view_sql.length
      ch = view_sql[pos]
      if ch == "("
        depth += 1
        buf << ch
        pos += 1
      elsif ch == ")"
        depth -= 1
        buf << ch
        pos += 1
      elsif depth.zero? && (m = view_sql[pos..].match(/\AUNION(?:\s+ALL)?/i))
        parts << buf.rstrip
        seps << m[0]
        buf = +""
        pos += m[0].length
        pos += 1 while pos < view_sql.length && view_sql[pos].match?(/\s/)
      else
        buf << ch
        pos += 1
      end
    end
    parts << buf.rstrip

    return view_sql if parts.size <= 1

    result_parts = parts.map do |part|
      # Strip any geometry references for tables not in this branch's FROM clause.
      # CartoDB sometimes referenced geometry from a table that only appears in a
      # different UNION branch (e.g. `sagcot_1.geom` in `SELECT … FROM vs_countries`).
      # After schema-qualification those become invalid 3-part identifiers; remove
      # them here so the correct geometry can be injected below.
      branch_tables = CartodbRakeHelpers.extract_table_names_from_sql(part)
      working_part = part.dup
      orphan_stripped = false
      geom_map.each do |tbl, gcol|
        next if branch_tables.include?(tbl)
        esc_tbl = Regexp.escape(tbl)
        esc_col = Regexp.escape(gcol)
        esc_sch = Regexp.escape(schema)
        [
          /\b#{esc_sch}\.#{esc_tbl}\.#{esc_col}\b[ \t]*,[ \t]*/i,
          /[ \t]*,[ \t]*\b#{esc_sch}\.#{esc_tbl}\.#{esc_col}\b/i,
          /\b#{esc_sch}\.#{esc_tbl}\.#{esc_col}\b/i,
          /\b#{esc_tbl}\.#{esc_col}\b[ \t]*,[ \t]*/i,
          /[ \t]*,[ \t]*\b#{esc_tbl}\.#{esc_col}\b/i,
          /\b#{esc_tbl}\.#{esc_col}\b/i
        ].each do |re|
          next unless working_part.match?(re)
          working_part = working_part.gsub(re, "")
          orphan_stripped = true
        end
      end
      if orphan_stripped
        working_part.gsub!(/\bSELECT\s*,/i, "SELECT")
        working_part.gsub!(/,\s*\bFROM\b/i, " FROM")
        working_part.gsub!(/[ \t]*,[ \t]*,[ \t]*/m, ", ")
      end

      # Does this branch already SELECT a known geometry column?
      already_has_geom = geom_col_names.any? do |col|
        working_part.match?(/\bSELECT\b.*\b#{Regexp.escape(col)}\b/im)
      end
      next working_part if already_has_geom

      # Find the geometry reference for this branch's primary FROM table.
      geom_ref = nil
      table_names.each do |tbl|
        next unless geom_map[tbl]
        next unless working_part.match?(/\b(?:FROM|JOIN)\s+(?:#{Regexp.escape(schema)}\.)?#{Regexp.escape(tbl)}\b/i)
        m = working_part.match(/\b(?:FROM|JOIN)\s+(?:#{Regexp.escape(schema)}\.)?#{Regexp.escape(tbl)}\s+(?:AS\s+)?([a-zA-Z_]\w*)\b/i)
        geom_ref = (m && !m[1].match?(SQL_KEYWORD_RE)) \
          ? "#{m[1]}.#{geom_map[tbl]}" \
          : geom_map[tbl]
        break
      end
      geom_ref ||= "NULL::geometry"
      inject_geometry_into_select(working_part, geom_ref)
    end

    result = result_parts.first.to_s
    seps.each_with_index { |sep, i| result += "\n#{sep}\n#{result_parts[i + 1]}" }
    result
  end

  # CartoDB always stored geometry as `the_geom`, but PostGIS tables imported
  # from GPKG files may use a different column name (e.g. `geom`, `wkb_geometry`,
  # `wkt_geom`).  Rename every `alias.the_geom` reference in `sql` to the actual
  # geometry column name for each matching table, as reported by geometry_columns.
  #
  # Returns [modified_sql, geom_ref_found] where geom_ref_found is true if at
  # least one geometry-bearing table was located in the SQL — meaning no further
  # geometry injection is needed regardless of whether a rename took place.
  def self.fix_the_geom_references(sql, schema, table_names, ar_conn)
    return [sql, false] if table_names.empty? || sql.blank?

    quoted = table_names.map { |t| "'#{ar_conn.quote_string(t)}'" }.join(", ")
    rows = ar_conn.execute(
      "SELECT f_table_name, f_geometry_column FROM geometry_columns " \
      "WHERE f_table_schema = '#{schema}' AND f_table_name IN (#{quoted})"
    ).map { |r| [r["f_table_name"], r["f_geometry_column"]] }

    return [sql, false] if rows.empty?

    result = sql.dup
    geom_ref_found = false

    rows.each do |tbl, geom_col|
      # Locate the alias used for this table in FROM/JOIN clauses
      m = sql.match(/\b(?:FROM|JOIN)\s+(?:#{Regexp.escape(schema)}\.)?#{Regexp.escape(tbl)}\s+(?:AS\s+)?([a-zA-Z_]\w*)\b/i)
      tbl_alias = (m && !m[1].match?(SQL_KEYWORD_RE)) ? m[1] : nil

      if tbl_alias
        pat = /\b#{Regexp.escape(tbl_alias)}\.the_geom\b/i
        if geom_col != "the_geom" && result.match?(pat)
          result = result.gsub(pat, "#{tbl_alias}.#{geom_col}")
          geom_ref_found = true
        elsif result.match?(/\b#{Regexp.escape(tbl_alias)}\.(?:the_geom|#{Regexp.escape(geom_col)})\b/i)
          geom_ref_found = true
        end
      end

      # Also handle schema.table.the_geom and bare table.the_geom references
      # (used when no alias is present in the original CartoDB SQL).
      next if geom_col == "the_geom"
      {
        /\b#{Regexp.escape(schema)}\.#{Regexp.escape(tbl)}\.the_geom\b/i => "#{schema}.#{tbl}.#{geom_col}",
        /\b#{Regexp.escape(tbl)}\.the_geom\b/i => "#{tbl}.#{geom_col}"
      }.each do |pat, rep|
        next unless result.match?(pat)
        result = result.gsub(pat, rep)
        geom_ref_found = true
      end
    end

    [result, geom_ref_found]
  end

  # Remove any remaining `alias.the_geom` or `schema.table.the_geom` references
  # from a SQL string.  Called when fix_the_geom_references was unable to rename
  # these refs — either because the associated table is not in geometry_columns
  # (e.g. a pure-attribute joined table like dhs_indicators) or because
  # geometry_columns listed the_geom but the physical column is absent.  After
  # stripping, the caller injects the correct geometry column via
  # inject_geometry_into_select.
  #
  # The strip is deliberately applied to the whole SQL string rather than just
  # the SELECT clause: in practice, CartoDB queries only place `alias.the_geom`
  # in the SELECT list, never in WHERE or ON predicates.
  def self.strip_the_geom_refs(sql)
    pat = /\b\w+(?:\.\w+)*\.the_geom\b/i
    result = sql
    # "alias.the_geom, " — first column or middle
    result = result.gsub(/#{pat}[ \t]*,[ \t]*/i, "")
    # ", alias.the_geom" — middle or last column
    result = result.gsub(/[ \t]*,[ \t]*#{pat}/i, "")
    # standalone (no commas left)
    result.gsub(pat, "")
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

    # Fill color: only use an explicit base CSS polygon-fill rule.
    # Do NOT fall back to the first conditional fill — if there is no base rule
    # (or it is transparent), the invisible-base guard below will fire and set
    # fill:false/fillOpacity:0/weight:0, which correctly matches CartoDB's own
    # behaviour: features that don't satisfy any conditional rule are invisible.
    fill_color = base_props["polygon-fill"]
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

    # polygon-pattern-file in the base rule: translate to a canvas hatch fill.
    # The line-colour is used as the hatch line colour, matching CartoDB output.
    if base_props["polygon-pattern-file"].present? && !path_opts.key?("fillPattern")
      hatch_color = path_opts["color"].presence || base_props["line-color"].presence
      path_opts["fillPattern"] = "hatch"
      path_opts["fillColor"] = hatch_color if hatch_color && !path_opts.key?("fillColor")
      path_opts["fillOpacity"] = 1
      path_opts["fill"] = true
    end

    # Build conditions array from conditional rules
    if conditional_rules.any?
      conds = conditional_rules.filter_map do |rule|
        pfill = rule[:styles]["polygon-fill"].to_s.strip
        popac = rule[:styles]["polygon-opacity"]
        lcolor = rule[:styles]["line-color"]
        lopac = rule[:styles]["line-opacity"]
        lwidth = rule[:styles]["line-width"]
        pattern = rule[:styles]["polygon-pattern-file"]
        overrides = {}

        if pattern.present?
          # polygon-pattern-file → canvas crosshatch fill.
          # polygon-opacity applies to the *solid* background, not the pattern;
          # ignore it and use full opacity for the hatch lines.
          hatch_color = lcolor.presence ||
            ((pfill.present? && pfill !~ /\Atransparent\z/i) ? pfill : nil)
          overrides["fillPattern"] = "hatch"
          overrides["fillColor"] = hatch_color if hatch_color
          overrides["fillOpacity"] = 1
          overrides["fill"] = true
        elsif pfill.match?(/\Atransparent\z/i)
          overrides["fillOpacity"] = 0
          overrides["fill"] = false
        elsif pfill.present?
          overrides["fillColor"] = pfill
          overrides["fill"] = true
          overrides["fillOpacity"] = popac.to_f if popac.present?
        elsif popac.present?
          overrides["fillOpacity"] = popac.to_f
        end

        overrides["color"] = lcolor if lcolor.present?
        overrides["opacity"] = lopac.to_f if lopac.present?
        # Stroke weight: use explicit value, or CartoDB default (1 px) when a
        # stroke colour is declared but no width is specified.
        if lwidth.present?
          overrides["weight"] = lwidth.to_f
        elsif lcolor.present?
          overrides["weight"] = 1.0
        end

        next if overrides.empty?
        {"when" => rule[:when]}.merge(overrides)
      end
      path_opts["conditions"] = conds if conds.any?
    end

    # When a layer has ONLY conditional rules and no base rule, CartoDB renders
    # non-matching features as completely transparent.  Set an explicit invisible
    # base so OL doesn't apply its own default (blue fill) to those features.
    if path_opts["conditions"]&.any? && (path_opts.keys - ["conditions"]).empty?
      path_opts = {"fill" => false, "fillOpacity" => 0, "weight" => 0}.merge(path_opts)
    end

    path_opts
  end

  # ---------------------------------------------------------------------------
  # Legend helpers
  # ---------------------------------------------------------------------------

  # Format a threshold float as a clean string label (no trailing ".0").
  def self.format_threshold(value)
    (value == value.floor) ? value.to_i.to_s : value.to_s
  end

  # Extract all [value <= N] → polygon-fill conditions from CartoDB CSS.
  # Returns an array of {threshold:, color:} hashes sorted ascending by threshold.
  def self.extract_value_conditions_from_css(css)
    return [] if css.blank?

    conditions = []
    css.scan(/#[\w-]+((?:\s*\[[^\]]*\])*)\s*\{([^}]+)\}/m).each do |filter_chain, declarations|
      next if filter_chain.nil? || filter_chain.strip.empty?

      props = {}
      declarations.scan(/([\w-]+)\s*:\s*([^;]+)/).each { |p, v| props[p.strip] = v.strip }
      pfill = props["polygon-fill"].to_s.strip
      next if pfill.blank? || pfill =~ /\Atransparent\z/i

      filters = filter_chain.scan(/\[([^\]]+)\]/).map(&:first)
      data_filters = filters.reject { |f| f.match?(/\Azoom\s*[<>=!]/i) }
      next unless data_filters.size == 1

      f = data_filters.first
      next unless (m = f.match(/\Avalue\s*<=\s*([-\d.]+)\z/i))

      conditions << {threshold: m[1].to_f, color: pfill}
    end

    conditions.sort_by { |c| c[:threshold] }
  end

  # Build a choropleth legend hash from CartoDB CSS [value <= N] conditions.
  # Buckets are ordered ascending by threshold; the first bucket includes a
  # "min-value" of "0".  Returns nil when the CSS has no usable conditions.
  def self.build_choropleth_legend_from_css(css)
    conditions = extract_value_conditions_from_css(css)
    return nil if conditions.empty?

    buckets = conditions.each_with_index.map do |cond, i|
      bucket = {"color" => cond[:color], "max-value" => format_threshold(cond[:threshold])}
      bucket["min-value"] = "0" if i.zero?
      bucket
    end

    {"type" => "choropleth", "bucket" => buckets}
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

    geom_col = geom_row["f_geometry_column"]
    srid = geom_row["srid"].to_i
    geom_expr = (srid == 4326) ? geom_col : "ST_Transform(#{geom_col}, 4326)"

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
      CARTODB_IMPORT_SCHEMA=<schema>    Target PostgreSQL schema for spatial vectors (default: ra_vector)
      CARTODB_NONSPATIAL_SCHEMA=<schema> Target schema for non-spatial .csv.gz tables (default: ra_nonspatial)
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
    nonspatial_schema = ENV.fetch("CARTODB_NONSPATIAL_SCHEMA", "ra_nonspatial")
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

      # ── 3. Ensure target schemas exist ────────────────────────────────────

      if target_schema != "public"
        ar_conn.execute("CREATE SCHEMA IF NOT EXISTS \"#{target_schema}\"")
        puts "Ensured schema '#{target_schema}' exists."
      end

      if nonspatial_schema != target_schema && nonspatial_schema != "public"
        ar_conn.execute("CREATE SCHEMA IF NOT EXISTS \"#{nonspatial_schema}\"")
        puts "Ensured schema '#{nonspatial_schema}' exists."
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
          # ar_conn.table_exists?("schema.table") is unreliable in Rails 7 when the
          # name is a dotted string — it may fail to parse the schema prefix and
          # return false even when the table exists.  Query information_schema directly.
          ar_conn.execute(
            "SELECT 1 FROM information_schema.tables " \
            "WHERE table_schema = #{ar_conn.quote(target_schema)} " \
            "  AND table_name   = #{ar_conn.quote(tbl)} LIMIT 1"
          ).ntuples > 0
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
            puts "\n  Table #{q_table} already exists — dropping before reimport (FORCE=1)."
            ar_conn.execute("DROP TABLE IF EXISTS #{q_table}")
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

        source_layer = CartodbRakeHelpers.detect_gpkg_layer_name(local_path)
        unless source_layer.present?
          warn "  FAILED: Could not detect a source layer inside #{basename}."
          failed_vectors << {table: tbl, file: basename, reason: "could not detect GeoPackage layer name"}
          begin
            File.delete(local_path)
          rescue
            nil
          end
          next
        end

        # Drop any pre-existing table before calling ogr2ogr.  The -overwrite
        # flag is unreliable with schema-qualified names in some ogr2ogr versions,
        # and a partial table left over from a failed previous run will cause
        # "relation already exists" even when the existence check says it's gone.
        begin
          ar_conn.execute("DROP TABLE IF EXISTS #{q_table} CASCADE")
        rescue => drop_err
          warn "  Warning: pre-import DROP failed (#{drop_err.message}) — proceeding anyway."
        end

        # Try progressively smaller batch sizes on OOM crash (large batches are
        # faster; only pathological files need small ones).
        batch_sizes = [65535, 1000, 100, 10]
        imported = false
        batch_sizes.each do |batch_size|
          puts "  Running ogr2ogr (layer=#{source_layer}, batch_size=#{batch_size})..."
          success = system(
            "ogr2ogr", "-f", "PostgreSQL",
            "PG:#{pg_conn}",
            local_path,
            source_layer,
            "-nln", tbl,
            "-lco", "SCHEMA=#{target_schema}",
            "-lco", "SPATIAL_INDEX=NONE",
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
        q_table = "\"#{nonspatial_schema}\".\"#{tbl}\""

        if ar_conn.table_exists?("#{nonspatial_schema}.#{tbl}")
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

      # ── 6. ANALYZE imported tables ────────────────────────────────────────
      # pg_stat_user_tables.n_live_tup and pg_class.reltuples both stay at 0
      # until PostgreSQL runs ANALYZE.  Run it now so the Dataset Inventory
      # shows accurate row counts immediately rather than waiting for autovacuum.

      all_imported = imported_vectors + imported_tables
      if all_imported.any?
        puts "\nRunning ANALYZE on #{all_imported.size} imported table(s) to update row count statistics..."
        imported_vectors.each do |t|
          q = "#{ar_conn.quote_table_name(target_schema)}.#{ar_conn.quote_table_name(t[:table])}"
          begin
            ar_conn.execute("ANALYZE #{q}")
          rescue => e
            warn "  WARNING: ANALYZE failed for #{q}: #{e.message.lines.first.strip}"
          end
        end
        imported_tables.each do |t|
          q = "#{ar_conn.quote_table_name(nonspatial_schema)}.#{ar_conn.quote_table_name(t[:table])}"
          begin
            ar_conn.execute("ANALYZE #{q}")
          rescue => e
            warn "  WARNING: ANALYZE failed for #{q}: #{e.message.lines.first.strip}"
          end
        end
        puts "Statistics updated."
      end

      # ── 7. Summary ────────────────────────────────────────────────────────

      puts "\n#{"=" * 60}"
      puts "  CartoDB Import — Summary"
      puts "=" * 60

      total_imported = imported_vectors.size + imported_tables.size
      total_failed = failed_vectors.size + failed_tables.size
      total_skipped = skipped_vectors.size + skipped_tables.size

      puts "  Imported : #{total_imported}"
      imported_vectors.each { |t| puts "    ✓  #{t[:src_schema]}.#{t[:table]} → #{target_schema}.#{t[:table]}  [vector, #{t[:rows]} features]" }
      imported_tables.each { |t| puts "    ✓  #{t[:src_schema]}.#{t[:table]} → #{nonspatial_schema}.#{t[:table]}  [nonspatial, #{t[:rows]} rows]" }

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
      CARTODB_IMPORT_SCHEMA=<schema>          Spatial vector schema (default: ra_vector)
      CARTODB_NONSPATIAL_SCHEMA=<schema>      Non-spatial table schema (default: ra_nonspatial)

    Usage:
      rake cartodb:update_layer_references
  DESC
  task update_layer_references: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    nonspatial_schema = ENV.fetch("CARTODB_NONSPATIAL_SCHEMA", "ra_nonspatial")

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

      local_tables = referenced.select do |t|
        ar_conn.table_exists?("#{target_schema}.#{t}") ||
          ar_conn.table_exists?("#{nonspatial_schema}.#{t}")
      end
      missing_tables = referenced - local_tables

      # Track which schema each local table lives in
      table_schemas = local_tables.each_with_object({}) do |t, h|
        h[t] = ar_conn.table_exists?("#{nonspatial_schema}.#{t}") ? nonspatial_schema : target_schema
      end
      nonspatial_local = local_tables.select { |t| table_schemas[t] == nonspatial_schema }
      spatial_local = local_tables - nonspatial_local

      puts "  Available locally : #{local_tables.any? ? local_tables.join(", ") : "(none)"}"
      puts "  Still missing     : #{missing_tables.any? ? missing_tables.join(", ") : "(none)"}"
      puts "  Nonspatial tables : #{nonspatial_local.join(", ")}" if nonspatial_local.any?

      # ── Build the cartodb_migration block for layer_config ─────────────

      table_status = referenced.each_with_object({}) do |t, h|
        h[t] = local_tables.include?(t) ? "imported" : "missing"
      end

      raster_layer = CartodbRakeHelpers.raster_layer?(layer, source_sql)
      raster_tables = raster_layer ? (referenced - local_tables) : []
      all_nonspatial = local_tables.any? && spatial_local.empty? && !raster_layer

      migration_block = {
        "status" => if raster_layer
                      raster_tables.any? ? "cog_pending" : "cog_ready"
                    elsif all_nonspatial
                      "nonspatial"
                    else
                      (local_tables.any? ? "partial" : "pending")
                    end,
        "tables" => table_status,
        "table_schemas" => table_schemas,
        "raster" => raster_layer,
        "raster_tables" => raster_tables,
        "nonspatial_only" => all_nonspatial,
        "source_sql" => source_sql,
        "cleaned_query" => CartodbRakeHelpers.strip_cartodb_columns(source_sql),
        "note" => if all_nonspatial
                    "All referenced tables are non-spatial; this layer has no tile geometry. " \
                    "Consider using it as a data source for charts/tables rather than a map layer."
                  else
                    "Set layer_provider and update layer_config, then set published=true."
                  end
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
    Configure raster-like CartoDB layers to use TiTiler-backed COGs, then repair
    all existing COG layers in the database.

    Phase 1 — configure newly-flagged layers (layer_provider=NULL, published=false):
      - Sets layer_provider = "cog"
      - Builds layer_config with body.source/body.sources pointing at converted COGs
      - Translates legacy CartoCSS raster stops into TiTiler render params
      - Publishes the layer when at least one COG source can be inferred

    Phase 2 — repair all existing COG layers:
      - Re-translates colormaps from original CartoCSS (fix_cog_styles)
      - Rebuilds body.sources for multi-table COG mosaic layers (fix_cog_sources)
      - Backfills clip geometry for ST_CLIP layers (fix_cog_clip)
      - Sets TiTiler point-query interaction_config (fix_cog_interactivity)

    Options:
      S3_BUCKET=<bucket>               Bucket containing converted COGs (default: resilienceatlas)
      COG_PREFIX=<prefix>              Prefix for converted COGs (default: cogs/)
      CARTODB_IMPORT_SCHEMA=<schema>   Vector schema (default: ra_vector)
      FORCE=1                          Overwrite existing interaction_config in Phase 2
      DRY_RUN=1                        Preview changes without saving

    Usage:
      rake cartodb:configure_cog_layers
      rake cartodb:configure_cog_layers DRY_RUN=1
      rake cartodb:configure_cog_layers FORCE=1
  DESC
  task configure_cog_layers: :environment do
    s3_bucket = ENV.fetch("S3_BUCKET", "resilienceatlas")
    cog_prefix = ENV.fetch("COG_PREFIX", "cogs/")
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    dry_run = ENV["DRY_RUN"] == "1"
    force = ENV["FORCE"] == "1"
    ar_conn = ActiveRecord::Base.connection

    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    # ── Phase 1: Configure newly-flagged COG layers ────────────────────────────

    configured_count = 0
    published_count = 0
    skipped_count = 0

    candidates = Layer
      .where(layer_provider: nil, published: false)
      .where("layer_config LIKE '%cartodb_migration%'")
      .order(:id)

    if candidates.empty?
      puts "No layers awaiting COG configuration."
    else
      puts "Found #{candidates.count} layer(s) to review for COG configuration.\n\n"

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
        # TiTiler requires a single-band input when a colormap is specified.
        # Parse the band number from the CartoDB SQL (ST_CLIP band argument);
        # falls back to 1, which is what CartoDB rendered when no band was given.
        body["bidx"] = CartodbRakeHelpers.extract_raster_band_from_sql(source_sql) if style["colormap"].present?

        # Extract clip geometry for ST_CLIP layers (boundary polygon stored for TiTiler)
        if source_sql.match?(/\bst_clip\s*\(/i)
          clip_geom = CartodbRakeHelpers.extract_clip_geometry(
            source_sql, ar_conn, target_schema
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
      puts "  configure_cog_layers#{dry_run ? " (DRY RUN)" : ""} — Phase 1 Summary"
      puts "=" * 56
      puts "  Configured : #{configured_count}"
      puts "    Published : #{published_count}"
      puts "  Skipped    : #{skipped_count}"
    end

    # ── Phase 2a: Re-translate colormaps for all existing COG layers ───────────

    puts "\n── Repairing existing COG layers ────────────────────────────────────────"

    cog_styles_updated = 0
    cog_styles_skipped = 0
    cog_styles_no_css = 0
    cog_sources_updated = 0
    cog_sources_skipped = 0
    cog_sources_no_sql = 0
    cog_clip_updated = 0
    cog_clip_skipped = 0
    cog_clip_no_clip = 0
    cog_ic_updated = 0
    cog_ic_skipped = 0
    cog_ic = CartodbRakeHelpers.build_cog_interaction_config

    Layer.where(layer_provider: "cog").find_each do |layer|
      config = begin
        JSON.parse(layer.layer_config)
      rescue
        {}
      end

      migration = config["cartodb_migration"] || {}
      changed = false

      # Resolve source SQL once — used by both the colormap and sources sections.
      source_sql = migration["source_sql"].presence || layer.query.to_s.strip

      # ── Colormap: re-translate CSS → TiTiler colormap/rescale ─────────────
      if layer.css.blank?
        if config.dig("body", "colormap").present?
          cog_styles_skipped += 1
        else
          puts "Layer ##{layer.id} (#{layer.slug}): no CSS and no colormap — skipping colormap"
          cog_styles_no_css += 1
        end
      else
        style = CartodbRakeHelpers.translate_raster_css(layer.css)
        if style["colormap"].blank?
          puts "Layer ##{layer.id} (#{layer.slug}): CSS yielded no colormap — skipping colormap"
          cog_styles_no_css += 1
        else
          new_colormap = style["colormap"]
          new_rescale = style["rescale"]
          new_mode = style["mode"]
          bidx_missing = config.dig("body", "colormap").present? && config.dig("body", "bidx").nil?
          if config.dig("body", "colormap") != new_colormap ||
              config.dig("body", "rescale") != new_rescale ||
              bidx_missing
            puts "Layer ##{layer.id} (#{layer.slug}): #{new_colormap.size} colormap entries, rescale=#{new_rescale}"
            config["body"]["colormap"] = new_colormap
            if new_rescale.present?
              config["body"]["rescale"] = new_rescale
            else
              config["body"].delete("rescale")
            end
            config["body"]["cartocss_mode"] = new_mode if new_mode.present?
            # TiTiler requires a single-band input when a colormap is specified.
            # Parse band from CartoDB SQL (ST_CLIP band arg); falls back to 1.
            # Use ||= so an explicitly-overridden bidx in the config is preserved.
            config["body"]["bidx"] ||= CartodbRakeHelpers.extract_raster_band_from_sql(source_sql)
            migration["style"] = style
            changed = true
            cog_styles_updated += 1
          else
            cog_styles_skipped += 1
          end
        end
      end

      # ── Sources: rebuild body.source/sources from source SQL ──────────────
      if source_sql.blank?
        cog_sources_no_sql += 1
      else
        referenced = CartodbRakeHelpers.extract_table_names_from_sql(source_sql)
        if referenced.empty?
          cog_sources_no_sql += 1
        else
          local_vector = referenced.select { |t| ar_conn.table_exists?("#{target_schema}.#{t}") }
          raster_tables = referenced - local_vector
          if raster_tables.empty?
            puts "Layer ##{layer.id} (#{layer.slug}): no raster tables found — skipping sources"
            cog_sources_no_sql += 1
          else
            sources = raster_tables.map { |t| CartodbRakeHelpers.build_cog_source_url(s3_bucket, cog_prefix, t) }
            current_sources =
              Array(config.dig("body", "sources")).presence ||
              [config.dig("body", "source")].compact
            if current_sources.sort == sources.sort
              cog_sources_skipped += 1
            else
              puts "Layer ##{layer.id} (#{layer.slug}): #{raster_tables.size} raster table(s)"
              puts "  Was: #{current_sources.join(", ")}"
              puts "  Now: #{sources.join(", ")}"
              config["body"]["source"] = sources.first
              config["body"]["sources"] = sources
              migration["raster_tables"] = raster_tables
              changed = true
              cog_sources_updated += 1
            end
          end
        end
      end

      # ── Clip geometry: backfill/refresh from ST_CLIP source SQL ──────────
      source_sql_for_clip = migration["source_sql"].presence || layer.query.to_s.strip
      if source_sql_for_clip.match?(/\bst_clip\s*\(/i)
        clip_geom = CartodbRakeHelpers.extract_clip_geometry(source_sql_for_clip, ar_conn, target_schema)
        if clip_geom.nil?
          puts "Layer ##{layer.id} (#{layer.slug}): ST_CLIP detected but boundary unavailable"
          cog_clip_skipped += 1
        elsif config.dig("body", "clip_geometry") == clip_geom
          cog_clip_skipped += 1
        else
          table = CartodbRakeHelpers.extract_clip_info(source_sql_for_clip)&.dig(:table)
          puts "Layer ##{layer.id} (#{layer.slug}): clip from #{table} → #{clip_geom.dig("geometry", "type")}"
          config["body"]["clip_geometry"] = clip_geom
          changed = true
          cog_clip_updated += 1
        end
      else
        cog_clip_no_clip += 1
      end

      # ── interaction_config: set standard TiTiler point-query template ─────
      ic_needs_update = force || layer.interaction_config.blank? ||
        layer.interaction_config == '{"output":[]}' ||
        layer.interaction_config == '{"output": []}'
      if ic_needs_update
        cog_ic_updated += 1
      else
        cog_ic_skipped += 1
      end

      # ── Persist all changes in a single write ─────────────────────────────
      config["cartodb_migration"] = migration
      unless dry_run
        if changed || ic_needs_update
          layer.update_columns(
            layer_config: config.to_json,
            interaction_config: ic_needs_update ? cog_ic.to_json : layer.interaction_config
          )
        end
      end
    end

    puts "  Colormap  updated : #{cog_styles_updated}"
    puts "  Colormap  skipped : #{cog_styles_skipped} (no change or no CSS)"
    puts "  Colormap  no CSS  : #{cog_styles_no_css} (CSS present but yielded no colormap)"
    puts "  Sources   updated : #{cog_sources_updated}"
    puts "  Sources   skipped : #{cog_sources_skipped} (already correct)"
    puts "  Sources   no SQL  : #{cog_sources_no_sql} (no source SQL found)"
    puts "  Clip      updated : #{cog_clip_updated}"
    puts "  Clip      skipped : #{cog_clip_skipped} (no change or boundary unavailable)"
    puts "  Clip      no clip : #{cog_clip_no_clip} (no ST_CLIP in source SQL)"
    puts "  Int.cfg   updated : #{cog_ic_updated}"
    puts "  Int.cfg   skipped : #{cog_ic_skipped} (already set; use FORCE=1 to overwrite)"
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Configure imported CartoDB layers to use the Martin tile server, then repair
    all existing Martin layers in the database.

    Phase 1 — configure newly-flagged layers (layer_provider=NULL, published=false):
      - Sets layer_provider = "martin"
      - Builds layer_config with body.source = "<schema>.<table>"
      - Sets published = true when ALL referenced tables are imported
      - Leaves published = false when some tables are still missing

    Phase 2 — repair all existing Martin layers:
      - Strips ra_vector. prefix from body.source IDs (fix_martin_sources)
      - Backfills missing OL PathOptions styles from CartoDB CSS (fix_martin_styles)
      - Builds click popup field list from PostGIS table columns (fix_martin_interactivity)

    Options:
      CARTODB_IMPORT_SCHEMA=<schema>  Schema used during import (default: ra_vector)
      FORCE=1                         Overwrite existing interaction_config in Phase 2
      DRY_RUN=1                       Preview changes without saving

    Usage:
      rake cartodb:configure_martin_layers
      rake cartodb:configure_martin_layers DRY_RUN=1
      rake cartodb:configure_martin_layers FORCE=1
  DESC
  task configure_martin_layers: :environment do
    target_schema = ENV.fetch("CARTODB_IMPORT_SCHEMA", "ra_vector")
    dry_run = ENV["DRY_RUN"] == "1"
    force = ENV["FORCE"] == "1"

    puts "DRY RUN — no changes will be saved.\n\n" if dry_run

    ar_conn = ActiveRecord::Base.connection

    # ── Phase 1: Configure newly-flagged Martin layers ─────────────────────────

    configured_count = 0
    published_count = 0
    skipped_count = 0
    view_count = 0

    candidates = Layer
      .where(layer_provider: nil, published: false)
      .where("layer_config LIKE '%cartodb_migration%'")
      .order(:id)

    if candidates.empty?
      puts "No layers awaiting Martin configuration."
    else
      puts "Found #{candidates.count} layer(s) to configure.\n\n"

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

        if migration["nonspatial_only"]
          puts "  - All referenced tables are non-spatial (no geometry) — cannot serve as Martin tile layer."
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

        # Build per-table schema map: spatial tables go to target_schema,
        # non-spatial (joined attribute) tables go to nonspatial_schema.
        migration_table_schemas = migration["table_schemas"] || {}
        table_schema_map = imported.each_with_object({}) do |t, h|
          h[t] = migration_table_schemas[t].presence || target_schema
        end
        # The primary table for Martin must be spatial (geometry-bearing).
        # Prefer the first table in target_schema; fall back to first imported.
        primary_table = imported.find { |t| table_schema_map[t] == target_schema } || imported.first

        source = if needs_view && layer.query.present?
          view_name = "v_layer_#{layer.id}"

          # Schema-qualify all FROM/JOIN table references using per-table schemas
          # (spatial tables → target_schema, nonspatial → nonspatial_schema).
          view_sql = CartodbRakeHelpers.qualify_table_names_in_sql_multi(
            layer.query, table_schema_map
          )

          # CartoDB always used `the_geom`, but GPKG-imported PostGIS tables may
          # use a different column name (e.g. `geom`, `wkb_geometry`, `wkt_geom`).
          # Rename any `alias.the_geom` references to the actual column name first.
          view_sql, geom_ref_present = CartodbRakeHelpers.fix_the_geom_references(
            view_sql, target_schema, imported, ar_conn
          )

          # Check whether any the_geom refs survived the rename pass.  This
          # happens when the alias maps to a non-geometry table (e.g. the ref
          # is on a joined attribute table) or when geometry_columns reports
          # the_geom but the physical column is absent.  In those cases we
          # strip the stale refs and inject the correct column below.
          still_has_the_geom = view_sql.match?(/\b\w+(?:\.\w+)*\.the_geom\b/i)

          # update_layer_references stripped the_geom via strip_cartodb_columns.
          # For a wildcard SELECT (*) the geometry column comes through anyway;
          # for explicit column lists we must add it back so Martin can generate
          # vector tiles.  Use PostGIS geometry_columns to identify which imported
          # table actually carries geometry (may not be the primary table).
          if !(view_sql.match?(/SELECT\s+\*/i) || (geom_ref_present && !still_has_the_geom))
            # Strip any stale the_geom refs that fix_the_geom_references could not
            # rename (e.g. refs on a non-geometry joined table).
            view_sql = CartodbRakeHelpers.strip_the_geom_refs(view_sql)
            geom_ref = CartodbRakeHelpers.find_geometry_column_ref(
              layer.query, target_schema, imported, ar_conn
            )
            if geom_ref
              view_sql = CartodbRakeHelpers.inject_geometry_into_select(view_sql, geom_ref)
            else
              warn "  ⚠  No geometry column found in imported tables — view may return no tiles."
            end
          end

          # For UNION queries, balance geometry across all SELECT branches.
          # fix_the_geom_references may have renamed the_geom in the first branch
          # but left subsequent branches without a geometry column, causing a
          # UNION column-count mismatch in PostgreSQL.
          if view_sql.match?(/\bUNION\b/i)
            view_sql = CartodbRakeHelpers.balance_union_geometry(
              view_sql, target_schema, imported, ar_conn
            )
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
            "source" => "ra_vector_tile",
            "params" => {"table" => source},
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
      puts "  configure_martin_layers#{dry_run ? " (DRY RUN)" : ""} — Phase 1 Summary"
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

    # ── Phase 2a: Strip ra_vector. prefix from Martin source IDs ──────────────

    puts "\n── Repairing existing Martin layers ─────────────────────────────────────"

    martin_sources_fixed = 0
    martin_sources_skipped = 0
    martin_views_upgraded = 0
    martin_styles_updated = 0
    martin_styles_skipped = 0
    martin_styles_no_css = 0
    martin_ic_updated = 0
    martin_ic_skipped = 0
    martin_ic_no_table = 0
    martin_legends_updated = 0
    martin_legends_skipped = 0
    martin_legends_no_css = 0

    Layer.where(layer_provider: "martin")
      .where("layer_config LIKE '%cartodb_migration%'").find_each do |layer|
      config = begin
        JSON.parse(layer.layer_config)
      rescue
        {}
      end

      changed = false

      # ── Source ID: strip ra_vector. prefix ────────────────────────────────
      source = config.dig("body", "source").to_s
      if source.start_with?("ra_vector.")
        bare_source = source.sub(/\Ara_vector\./, "")
        puts "Layer ##{layer.id}: #{source} → #{bare_source}"
        config["body"]["source"] = bare_source
        source = bare_source
        changed = true
        martin_sources_fixed += 1
      end

      # view_source is the actual ra_vector table/view name.  When the layer
      # already uses the ra_vector_tile function source, params.table holds it.
      view_source = config.dig("body", "params", "table").presence || source

      # ── Source upgrade: create view when all tables are now available ──────
      # Phase 1 may have set source to a bare table because some tables were
      # still missing at the time.  When all tables are now imported AND the
      # layer requires a JOIN/CTE, create the proper view so Martin can serve
      # vector tiles with geometry.
      migration_block = config["cartodb_migration"] || {}
      tables_status = migration_block["tables"] || {}
      imported_list = tables_status.select { |_, v| v == "imported" }.keys
      raw_sql = migration_block["source_sql"].presence ||
        migration_block["cleaned_query"].presence

      # Normalise whitespace: CartoDB SQL stored in the DB sometimes has
      # collapsed newlines that removed the space between a clause-ending
      # token and the next SQL keyword (e.g. `landscape_noWHERE`).
      raw_sql = CartodbRakeHelpers.fix_sql_keyword_spacing(raw_sql) if raw_sql.present?

      # Detect whether a previously-created view was dropped (e.g. after a
      # database restore).  When the source already looks like v_layer_N but
      # the view no longer exists in the database we must recreate it.
      # Use view_source (the actual table/view name) since source may already
      # be "ra_vector_tile" if the layer was previously migrated.
      view_gone = view_source.match?(/\Av_layer_\d+\z/) &&
        raw_sql.present? &&
        ar_conn.execute(
          "SELECT 1 FROM pg_catalog.pg_views " \
          "WHERE schemaname = '#{ar_conn.quote_string(target_schema)}' " \
          "AND viewname = '#{ar_conn.quote_string(view_source)}'"
        ).ntuples.zero?

      # Detect whether an existing view has broken geometry: SRID=0 in
      # geometry_columns causes ST_Transform to error (HTTP 500); all-NULL
      # geometry causes empty tiles (HTTP 204).  Both stem from
      # find_geometry_column_ref previously selecting the wrong table's geom
      # column.  Re-derive the view SQL with the corrected ordering so the
      # next task run heals already-configured layers automatically.
      view_has_bad_geom = view_source.match?(/\Av_layer_\d+\z/) &&
        raw_sql.present? &&
        !view_gone &&
        begin
          vgeom = ar_conn.execute(
            "SELECT f_geometry_column, srid FROM geometry_columns " \
            "WHERE f_table_schema = '#{ar_conn.quote_string(target_schema)}' " \
            "AND f_table_name = '#{ar_conn.quote_string(view_source)}'"
          ).first
          if vgeom
            gcol = vgeom["f_geometry_column"]
            vgeom["srid"].to_i.zero? ||
              ar_conn.execute(
                "SELECT 1 FROM \"#{target_schema}\".\"#{view_source}\" " \
                "WHERE \"#{gcol}\" IS NOT NULL LIMIT 1"
              ).ntuples.zero?
          else
            false
          end
        rescue
          false
        end

      upgrade_to_view = raw_sql.present? &&
        ((imported_list.size > 1 && !view_source.match?(/\Av_layer_\d+\z/)) ||
         view_gone ||
         view_has_bad_geom)

      if upgrade_to_view
        # When recovering a dropped view, keep the same name so existing
        # layer_config references remain valid.
        view_name = view_source.match?(/\Av_layer_\d+\z/) ? view_source : "v_layer_#{layer.id}"
        p2_table_schemas = migration_block["table_schemas"] || {}
        p2_schema_map = imported_list.each_with_object({}) do |t, h|
          h[t] = p2_table_schemas[t].presence || target_schema
        end
        view_sql = CartodbRakeHelpers.qualify_table_names_in_sql_multi(
          raw_sql, p2_schema_map
        )

        # Fix any "SELECT  FROM table" patterns left by strip_cartodb_columns
        # having removed the_geom as the sole column of a subquery SELECT (e.g.
        # `st_intersects((select the_geom from t where ...))` → `select  from t`).
        view_sql = CartodbRakeHelpers.fix_empty_subquery_selects(
          view_sql, target_schema, ar_conn
        )

        # CartoDB always used `the_geom`, but GPKG-imported PostGIS tables may
        # use a different column name (e.g. `geom`, `wkb_geometry`, `wkt_geom`).
        # Rename any `alias.the_geom` references to the actual column name first.
        view_sql, geom_ref_present = CartodbRakeHelpers.fix_the_geom_references(
          view_sql, target_schema, imported_list, ar_conn
        )

        # Check whether any the_geom refs survived the rename pass.  This
        # happens when the alias maps to a non-geometry table (e.g. the ref
        # is on a joined attribute table) or when geometry_columns reports
        # the_geom but the physical column is absent.  In those cases we
        # strip the stale refs and inject the correct column below.
        still_has_the_geom = view_sql.match?(/\b\w+(?:\.\w+)*\.the_geom\b/i)

        if !(view_sql.match?(/SELECT\s+\*/i) || (geom_ref_present && !still_has_the_geom))
          # Strip any stale the_geom refs that fix_the_geom_references could not
          # rename (e.g. refs on a non-geometry joined table like dhs_indicators).
          view_sql = CartodbRakeHelpers.strip_the_geom_refs(view_sql)
          # For UNION queries, geometry injection is deferred to balance_union_geometry
          # which handles each branch independently.  Injecting here would bind the
          # geometry of one branch's table into all branches via the outermost SELECT.
          unless view_sql.match?(/\bUNION\b/i)
            geom_ref = CartodbRakeHelpers.find_geometry_column_ref(
              raw_sql, target_schema, imported_list, ar_conn
            )
            if geom_ref
              view_sql = CartodbRakeHelpers.inject_geometry_into_select(view_sql, geom_ref)
            else
              puts "Layer ##{layer.id} (#{layer.slug}): ⚠ no geometry table found — view upgrade skipped"
              upgrade_to_view = false
            end
          end
        end
      end

      # For UNION queries, balance geometry across all SELECT branches.
      # fix_the_geom_references may have renamed the_geom in the first branch
      # but left subsequent branches without a geometry column, causing a
      # UNION column-count mismatch in PostgreSQL.
      if upgrade_to_view && view_sql.match?(/\bUNION\b/i)
        view_sql = CartodbRakeHelpers.balance_union_geometry(
          view_sql, target_schema, imported_list, ar_conn
        )
      end

      if upgrade_to_view
        create_ddl = "CREATE OR REPLACE VIEW #{target_schema}.#{view_name} AS #{view_sql}"
        puts "Layer ##{layer.id} (#{layer.slug}): source upgrade #{source} → #{view_name}"
        puts "  SQL: #{view_sql}"

        if dry_run
          martin_views_upgraded += 1
        else
          begin
            ar_conn.execute(create_ddl)
            config["body"]["source"] = "ra_vector_tile"
            config["body"]["params"] = (config["body"]["params"] || {}).merge("table" => view_name)
            view_source = view_name
            source = "ra_vector_tile"
            migration_block["status"] = "configured"
            config["cartodb_migration"] = migration_block
            changed = true
            martin_views_upgraded += 1
            # Publish the layer now that all tables are available
            layer.update_column(:published, true) unless layer.published?
          rescue PG::UndefinedColumn => e
            # Show the actual columns available in each source table so the
            # underlying source_sql can be corrected in the database.
            if (m = e.message.match(/column ([\w."]+) does not exist/i))
              missing_ref = m[1].gsub('"', "")
              tbl_alias = missing_ref.include?(".") ? missing_ref.split(".").first : nil
              imported_list.each do |tbl|
                next if tbl_alias && !view_sql.match?(
                  /\b(?:FROM|JOIN)\s+(?:"?#{Regexp.escape(target_schema)}"?\.)?"?#{Regexp.escape(tbl)}"?\s+(?:AS\s+)?"?#{Regexp.escape(tbl_alias)}"?\b/i
                )
                actual_cols = ar_conn.execute(
                  "SELECT column_name FROM information_schema.columns " \
                  "WHERE table_schema = #{ar_conn.quote(target_schema)} " \
                  "AND table_name = #{ar_conn.quote(tbl)} " \
                  "ORDER BY ordinal_position"
                ).map { |r| r["column_name"] }
                warn "  Available columns in #{target_schema}.#{tbl}: #{actual_cols.join(", ")}" if actual_cols.any?
              end
            end
            warn "Layer ##{layer.id}: ✗ view creation failed: #{e.message}"
          rescue => e
            warn "Layer ##{layer.id}: ✗ view creation failed: #{e.message}"
          end
        end
      end

      # ── Upgrade bare table/view name → ra_vector_tile function source ──────
      # Martin only exposes the ra_vector_tile function, not individual tables
      # or views as direct sources.  Any layer whose body.source is still a
      # bare ra_vector name (not yet upgraded by the migration or a previous
      # rake run) must be wrapped here.
      if source != "ra_vector_tile" && source.present? &&
          ar_conn.execute(
            "SELECT 1 FROM pg_class c " \
            "JOIN pg_namespace n ON n.oid = c.relnamespace " \
            "WHERE n.nspname = 'ra_vector' AND c.relname = #{ar_conn.quote(source)} " \
            "AND c.relkind IN ('r', 'v', 'm') LIMIT 1"
          ).ntuples > 0
        puts "Layer ##{layer.id} (#{layer.slug}): upgrade #{source} → ra_vector_tile (table=#{source})"
        config["body"]["params"] = (config["body"]["params"] || {}).merge("table" => source)
        config["body"]["source"] = "ra_vector_tile"
        view_source = source
        source = "ra_vector_tile"
        changed = true
        martin_sources_fixed += 1
      else
        martin_sources_skipped += 1
      end

      # table_name: the actual ra_vector table/view used as the MVT layer name
      # by Martin's ST_AsMVT call (not "ra_vector_tile").  Used for styles and IC.
      table_name = view_source

      # ── Styles: re-derive from CartoDB CSS on every run ───────────────────
      # Always re-translate so fixes to translate_vector_css are applied even
      # when styles were already set by an earlier (buggy) run.
      if layer.css.blank?
        puts "Layer ##{layer.id} (#{layer.slug}): no CSS — skipping styles"
        martin_styles_no_css += 1
      else
        translated = CartodbRakeHelpers.translate_vector_css(layer.css)
        if translated.blank?
          puts "Layer ##{layer.id} (#{layer.slug}): CSS yielded no usable styles — skipping styles"
          martin_styles_no_css += 1
        else
          new_styles = table_name.present? ? {table_name => translated} : translated
          if config.dig("body", "styles") == new_styles
            martin_styles_skipped += 1
          else
            puts "Layer ##{layer.id} (#{layer.slug}): #{new_styles.to_json}"
            config["body"]["styles"] = new_styles
            changed = true
            martin_styles_updated += 1
          end
        end
      end

      # ── Legend: repair missing or incomplete choropleth legend ────────────
      # Rebuilds or repairs the choropleth legend from CartoDB CSS whenever
      # the legend is blank, or the bucket objects are missing their color keys.
      # Preserves existing bucket labels (e.g. "40%") when the bucket count
      # matches the CSS conditions; falls back to raw numeric labels otherwise.
      if layer.css.present?
        css_conditions = CartodbRakeHelpers.extract_value_conditions_from_css(layer.css)

        if css_conditions.any?
          current_legend_str = layer.legend.presence
          current_legend = begin
            JSON.parse(current_legend_str || "{}")
          rescue
            {}
          end

          needs_legend_fix = force ||
            if current_legend["type"] == "choropleth" &&
                current_legend["bucket"].is_a?(Array) &&
                current_legend["bucket"].first.is_a?(Hash)
              # Object-format buckets: fix if any bucket is missing its color
              current_legend["bucket"].any? { |b| b["color"].blank? }
            else
              !(current_legend["type"] == "choropleth" &&
                current_legend["bucket"].is_a?(Array) &&
                current_legend["bucket"].first.is_a?(String))
            end

          if needs_legend_fix
            existing_buckets =
              if current_legend["bucket"].is_a?(Array) &&
                  current_legend["bucket"].first.is_a?(Hash)
                current_legend["bucket"]
              end

            legend_data =
              if existing_buckets && existing_buckets.size == css_conditions.size
                # Preserve existing labels; fill in colors from CSS in ascending order
                new_buckets = existing_buckets.each_with_index.map do |b, i|
                  b.merge("color" => css_conditions[i][:color])
                end
                {"type" => "choropleth", "bucket" => new_buckets}
              else
                # Build from scratch with raw numeric threshold labels
                CartodbRakeHelpers.build_choropleth_legend_from_css(layer.css)
              end

            if legend_data
              unless dry_run
                ar_conn.execute(
                  "UPDATE layer_translations " \
                  "SET legend = #{ar_conn.quote(legend_data.to_json)} " \
                  "WHERE layer_id = #{layer.id}"
                )
              end
              puts "Layer ##{layer.id} (#{layer.slug}): legend repaired (#{legend_data["bucket"].size} buckets)"
              martin_legends_updated += 1
            else
              martin_legends_skipped += 1
            end
          else
            martin_legends_skipped += 1
          end
        else
          martin_legends_no_css += 1
        end
      else
        martin_legends_no_css += 1
      end

      # ── interaction_config: build from PostGIS table columns ──────────────
      ic_needs_update = force || layer.interaction_config.blank? ||
        layer.interaction_config == '{"output":[]}' ||
        layer.interaction_config == '{"output": []}'

      if ic_needs_update
        if table_name.blank?
          martin_ic_no_table += 1
        else
          ic = CartodbRakeHelpers.build_martin_interaction_config(table_name, ar_conn, target_schema)
          if ic
            puts "Layer ##{layer.id} (#{layer.slug}): #{ic["output"].size} columns from #{table_name}"
            unless dry_run
              layer.update_column(:interaction_config, ic.to_json)
            end
            martin_ic_updated += 1
          else
            puts "Layer ##{layer.id} (#{layer.slug}): no data columns in #{source}"
            martin_ic_no_table += 1
          end
        end
      else
        martin_ic_skipped += 1
      end

      # ── Persist layer_config changes in a single write ────────────────────
      unless dry_run
        layer.update_column(:layer_config, config.to_json) if changed
      end
    end

    puts "  Source ID fixed   : #{martin_sources_fixed}"
    puts "  Source ID skipped : #{martin_sources_skipped} (already correct)"
    puts "  Views upgraded    : #{martin_views_upgraded} (partial → full view)"
    puts "  Styles  updated   : #{martin_styles_updated}"
    puts "  Styles  skipped   : #{martin_styles_skipped} (no change)"
    puts "  Styles  no CSS    : #{martin_styles_no_css} (no CSS or unrecognised CSS)"
    puts "  Legend  updated   : #{martin_legends_updated}"
    puts "  Legend  skipped   : #{martin_legends_skipped} (already correct; use FORCE=1 to rebuild)"
    puts "  Legend  no CSS    : #{martin_legends_no_css} (no CSS or no [value <= N] conditions)"
    puts "  Int.cfg updated   : #{martin_ic_updated}"
    puts "  Int.cfg skipped   : #{martin_ic_skipped} (already set; use FORCE=1 to overwrite)"
    puts "  Int.cfg no table  : #{martin_ic_no_table} (source table not found or no data columns)"
    puts "  Restart Martin if any source IDs were fixed: docker service update --force <stack>_martin" if martin_sources_fixed > 0 && !dry_run
  end

  # ---------------------------------------------------------------------------

  desc <<~DESC
    Full CartoDB migration pipeline — import, configure, and repair in one command.

    Steps (run in order):
       1. import_tables             — download and import .gpkg / .csv.gz files from S3
       2. update_layer_references   — parse SQL, classify raster vs vector, strip CartoDB columns
       3. configure_cog_layers      — configure new COG layers + repair all existing COG layers
       4. configure_martin_layers   — configure new Martin layers + repair all existing Martin layers

    configure_cog_layers and configure_martin_layers each include a repair phase
    that ensures all layers in the database are correct, not just newly configured
    ones.  migrate_tables is safe to re-run at any time.

    Accepts all environment variables from the sub-tasks:
      CARTODB_S3_BUCKET, CARTODB_VECTORS_S3_PREFIX, CARTODB_TABLES_S3_PREFIX,
      CARTODB_EXPORT_DIR, CARTODB_IMPORT_SCHEMA, CARTODB_NONSPATIAL_SCHEMA,
      S3_BUCKET, COG_PREFIX, FORCE

    Usage:
      rake cartodb:migrate_tables CARTODB_S3_BUCKET=resilienceatlas
      rake cartodb:migrate_tables CARTODB_S3_BUCKET=resilienceatlas FORCE=1
  DESC
  task migrate_tables: [
    "cartodb:import_tables",
    "cartodb:update_layer_references",
    "cartodb:configure_cog_layers",
    "cartodb:configure_martin_layers"
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
