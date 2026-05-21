# Scans PostgreSQL schemas (ra_vector, ra_raster) and S3 COG objects and
# returns a paginated, sortable, filterable summary of each asset with
# the layers that reference it.
class DatasetInventoryService
  VECTOR_SCHEMA = "ra_vector"
  RASTER_SCHEMA = "ra_raster"
  NONSPATIAL_SCHEMA = "ra_nonspatial"
  TABLE_SORT_COLS = %w[name row_count size_bytes].freeze
  S3_SORT_COLS = %w[key size_bytes layers].freeze

  attr_reader :s3_error, :table_data_error

  # Returns {rows:, total:, page:, per_page:} – filterable/sortable/paginated.
  def vector_tables(page: 1, per_page: 25, sort: "name", dir: "asc", q: nil, lq: nil)
    filter_sort_paginate(all_vector_rows, page: page, per_page: per_page,
      sort: sort, dir: dir, q: q, lq: lq, valid_sorts: TABLE_SORT_COLS)
  end

  def raster_tables(page: 1, per_page: 25, sort: "name", dir: "asc", q: nil, lq: nil)
    filter_sort_paginate(all_raster_rows, page: page, per_page: per_page,
      sort: sort, dir: dir, q: q, lq: lq, valid_sorts: TABLE_SORT_COLS)
  end

  def nonspatial_tables(page: 1, per_page: 25, sort: "name", dir: "asc", q: nil, lq: nil)
    filter_sort_paginate(all_nonspatial_rows, page: page, per_page: per_page,
      sort: sort, dir: dir, q: q, lq: lq, valid_sorts: TABLE_SORT_COLS)
  end

  # Returns {rows:, total:, page:, per_page:}. Sets #s3_error on failure.
  def s3_cogs(page: 1, per_page: 25, sort: "key", dir: "asc", q: nil, lq: nil)
    all = all_s3_rows
    return {rows: [], total: 0, page: 1, per_page: per_page} if all.nil?

    rows = all
    rows = rows.select { |r| r[:key].to_s.downcase.include?(q.downcase) } if q.present?
    if lq.present?
      rows = rows.select do |r|
        r[:layers].any? { |l| "#{l[:name]} #{l[:slug]}".downcase.include?(lq.downcase) }
      end
    end

    safe_sort = S3_SORT_COLS.include?(sort) ? sort : "key"
    rows = rows.sort_by do |r|
      case safe_sort
      when "size_bytes" then r[:size_bytes].to_i
      when "layers" then r[:layers].size
      else r[:key].to_s.downcase
      end
    end
    rows.reverse! if dir == "desc"

    total = rows.size
    {rows: rows.slice([(page.to_i - 1) * per_page, 0].max, per_page) || [],
     total: total, page: page.to_i, per_page: per_page}
  end

  # Read-only paginated view of an arbitrary table in a managed schema.
  # Returns nil (and sets #table_data_error) if the table is not found or inaccessible.
  def table_data(schema, table_name, page: 1, per_page: 50)
    unless valid_table?(schema, table_name)
      @table_data_error = "Table #{schema}.#{table_name} not found in managed schemas."
      return nil
    end

    quoted = "#{conn.quote_table_name(schema)}.#{conn.quote_table_name(table_name)}"
    total = conn.select_value("SELECT COUNT(*) FROM #{quoted}").to_i
    offset = ([page.to_i, 1].max - 1) * per_page
    result = conn.select_all("SELECT * FROM #{quoted} LIMIT #{per_page.to_i} OFFSET #{offset.to_i}")
    {columns: result.columns, rows: result.rows, total: total, page: page.to_i, per_page: per_page}
  rescue => e
    @table_data_error = e.message
    nil
  end

  private

  def conn
    @conn ||= ActiveRecord::Base.connection
  end

  def all_vector_rows
    @all_vector_rows ||= pg_tables([VECTOR_SCHEMA]).map do |row|
      row.merge(layers: layer_usage_by_table[row[:name]] || [])
    end
  end

  def all_raster_rows
    @all_raster_rows ||= pg_tables([RASTER_SCHEMA]).map do |row|
      row.merge(layers: layer_usage_by_table[row[:name]] || [])
    end
  end

  def all_nonspatial_rows
    @all_nonspatial_rows ||= pg_tables([NONSPATIAL_SCHEMA]).map do |row|
      row.merge(layers: layer_usage_by_table[row[:name]] || [])
    end
  end

  def all_s3_rows
    @all_s3_rows ||= fetch_s3_cogs
  end

  def filter_sort_paginate(rows, page:, per_page:, sort:, dir:, q:, lq:, valid_sorts:)
    rows = rows.select { |r| r[:name].to_s.downcase.include?(q.downcase) } if q.present?
    if lq.present?
      rows = rows.select do |r|
        r[:layers].any? { |l| "#{l[:name]} #{l[:slug]}".downcase.include?(lq.downcase) }
      end
    end

    safe_sort = valid_sorts.include?(sort) ? sort.to_sym : :name
    rows = rows.sort_by { |r| [r[safe_sort].to_s.downcase, r[:name].to_s.downcase] }
    rows.reverse! if dir == "desc"

    total = rows.size
    {rows: rows.slice([(page.to_i - 1) * per_page, 0].max, per_page) || [],
     total: total, page: page.to_i, per_page: per_page}
  end

  def valid_table?(schema, table_name)
    return false unless [VECTOR_SCHEMA, RASTER_SCHEMA, NONSPATIAL_SCHEMA].include?(schema.to_s)

    (all_vector_rows + all_raster_rows + all_nonspatial_rows).any? do |t|
      t[:schema] == schema.to_s && t[:name] == table_name.to_s
    end
  end

  # ── PostgreSQL inventory ────────────────────────────────────────────────────

  def pg_tables(schemas)
    quoted_schemas = schemas.map { |s| conn.quote(s) }.join(", ")
    rows = conn.execute(<<~SQL)
      SELECT
        t.table_schema,
        t.table_name,
        GREATEST(
          COALESCE(s.n_live_tup, 0),
          CASE WHEN c.reltuples > 0 THEN c.reltuples::bigint ELSE 0 END
        )::bigint AS row_count,
        pg_total_relation_size(
          quote_ident(t.table_schema) || '.' || quote_ident(t.table_name)
        )::bigint AS size_bytes
      FROM information_schema.tables t
      LEFT JOIN pg_stat_user_tables s
        ON s.schemaname = t.table_schema AND s.relname = t.table_name
      JOIN pg_namespace n ON n.nspname = t.table_schema
      JOIN pg_class c ON c.relname = t.table_name AND c.relnamespace = n.oid
      WHERE t.table_schema IN (#{quoted_schemas})
        AND t.table_type IN ('BASE TABLE', 'VIEW')
      ORDER BY t.table_schema, t.table_name
    SQL

    rows.map do |r|
      row_count = r["row_count"].to_i
      # If both pg_stat and pg_class show 0 (freshly imported tables not yet
      # ANALYZEd by autovacuum), fall back to an exact COUNT(*).
      if row_count == 0
        quoted_table = "#{conn.quote_table_name(r["table_schema"])}.#{conn.quote_table_name(r["table_name"])}"
        row_count = conn.select_value("SELECT COUNT(*) FROM #{quoted_table}").to_i
      end
      {name: r["table_name"], schema: r["table_schema"],
       row_count: row_count, size_bytes: r["size_bytes"].to_i}
    end
  end

  # Build a map: bare table_name => [layer_summary, ...]
  def layer_usage_by_table
    @layer_usage_by_table ||= begin
      usage = Hash.new { |h, k| h[k] = [] }

      Layer.find_each do |layer|
        summary = layer_summary(layer)

        [layer.query, layer.analysis_query].compact.each do |sql|
          LayerTableParser.tables_from_sql(sql).each { |tbl| usage[tbl] << summary }
        end

        if layer.layer_provider == "martin"
          tbl = LayerTableParser.resolve_martin_table(layer, conn)
          usage[tbl] << summary if tbl.present?

          raw_source = LayerTableParser.source_from_config(layer)
          usage[raw_source] << summary if raw_source.present? && raw_source != tbl
        end
      end

      usage.transform_values { |layers| layers.uniq { |l| l[:id] } }
    end
  end

  def layer_summary(layer)
    {id: layer.id, slug: layer.slug, name: layer.name}
  end

  # ── S3 inventory ─────────────────────────────────────────────────────────────

  def fetch_s3_cogs
    bucket = ENV["S3_BUCKET"].presence || "resilienceatlas"
    prefix = ENV["COG_PREFIX"].presence || "cogs/"
    prefix = "#{prefix}/" unless prefix.end_with?("/")

    client = build_s3_client
    results = []
    cog_layers_by_key = build_cog_layer_index

    continuation_token = nil
    loop do
      opts = {bucket: bucket, prefix: prefix, max_keys: 1000}
      opts[:continuation_token] = continuation_token if continuation_token

      resp = client.list_objects_v2(**opts)
      resp.contents.each do |obj|
        results << {key: obj.key, size_bytes: obj.size,
                    layers: cog_layers_by_key[obj.key] || []}
      end

      break unless resp.is_truncated
      continuation_token = resp.next_continuation_token
    end

    results
  rescue Aws::S3::Errors::ServiceError, Aws::Errors::MissingCredentialsError => e
    @s3_error = e.message
    nil
  rescue => e
    @s3_error = "S3 unavailable: #{e.message}"
    nil
  end

  def build_cog_layer_index
    index = Hash.new { |h, k| h[k] = [] }
    bucket = ENV["S3_BUCKET"].presence || "resilienceatlas"

    Layer.where(layer_provider: "cog").find_each do |layer|
      uri = LayerTableParser.source_from_config(layer)
      next if uri.blank?

      key = uri.sub(%r{\As3://#{Regexp.escape(bucket)}/}, "").sub(%r{\As3://[^/]+/}, "")
      index[key] << layer_summary(layer)

      ab_uri = LayerTableParser.s3_uri_from_analysis_body(layer)
      if ab_uri.present?
        ab_key = ab_uri.sub(%r{\As3://[^/]+/}, "")
        index[ab_key] << layer_summary(layer)
      end
    end

    index.transform_values { |layers| layers.uniq { |l| l[:id] } }
  end

  def build_s3_client
    Aws::S3::Client.new(
      region: ENV["AWS_REGION"].presence || "us-east-1",
      access_key_id: ENV["AWS_ACCESS_KEY_ID"].presence,
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"].presence
    )
  end
end
