# Scans PostgreSQL schemas (ra_vector, ra_raster) and S3 COG objects and
# returns a paginated, sortable, filterable summary of each asset with
# the layers that reference it.
#
# Layer-to-table and layer-to-COG association maps are cached in Redis to avoid
# a full Layer scan + SQL parsing on every page load. The cache is automatically
# invalidated when any Layer is saved or destroyed (Layer after_commit callback).
# Use +invalidate_all_caches!+ or the admin "Refresh Cache" action for a full reset.
class DatasetInventoryService
  VECTOR_SCHEMA = "ra_vector"
  RASTER_SCHEMA = "ra_raster"
  NONSPATIAL_SCHEMA = "ra_nonspatial"
  TABLE_SORT_COLS = %w[name row_count size_bytes].freeze
  S3_SORT_COLS = %w[key size_bytes layers].freeze

  # Cache keys
  LAYER_USAGE_CACHE_KEY = "dataset_inventory/layer_usage"
  S3_RAW_CACHE_KEY      = "dataset_inventory/s3_raw"

  # Cache TTLs — these are safety-net fallbacks only; primary invalidation happens
  # via explicit cache busting at every write path (Layer after_commit, upload actions,
  # import jobs) so the TTL rarely triggers in normal operation.
  LAYER_USAGE_TTL = 1.hour
  PG_TABLES_TTL   = 1.hour
  S3_RAW_TTL      = 2.hours

  attr_reader :s3_error, :table_data_error

  # Invalidate only the layer-usage map. Called by Layer#after_commit so the
  # cache is refreshed automatically after any layer save or destroy.
  def self.invalidate_layer_cache!
    Rails.cache.delete(LAYER_USAGE_CACHE_KEY)
  end

  # Invalidate all dataset inventory caches (called by the admin Refresh Cache action).
  def self.invalidate_all_caches!
    Rails.cache.delete(LAYER_USAGE_CACHE_KEY)
    Rails.cache.delete(S3_RAW_CACHE_KEY)
    [VECTOR_SCHEMA, RASTER_SCHEMA, NONSPATIAL_SCHEMA].each do |schema|
      Rails.cache.delete("dataset_inventory/pg_tables/#{schema}")
    end
  end

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
    cache_key = "dataset_inventory/pg_tables/#{schemas.sort.join(",")}"
    Rails.cache.fetch(cache_key, expires_in: PG_TABLES_TTL) do
      fetch_pg_tables(schemas)
    end
  end

  def fetch_pg_tables(schemas)
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

  # Single Layer.find_each pass that builds both the table-usage map and the
  # COG-key index. Result is cached in Redis and shared by all three schema
  # sections and the S3 tab, so layers are scanned only once per cache period.
  # Automatically invalidated via Layer#after_commit.
  def layer_usage_maps
    @layer_usage_maps ||= Rails.cache.fetch(LAYER_USAGE_CACHE_KEY, expires_in: LAYER_USAGE_TTL) do
      table_usage = Hash.new { |h, k| h[k] = [] }
      cog_index   = Hash.new { |h, k| h[k] = [] }
      bucket      = ENV["S3_BUCKET"].presence || "resilienceatlas"

      Layer.find_each do |layer|
        summary = layer_summary(layer)

        [layer.query, layer.analysis_query].compact.each do |sql|
          LayerTableParser.tables_from_sql(sql).each { |tbl| table_usage[tbl] << summary }
        end

        if layer.layer_provider == "martin"
          tbl = LayerTableParser.resolve_martin_table(layer, conn)
          table_usage[tbl] << summary if tbl.present?

          raw_source = LayerTableParser.source_from_config(layer)
          table_usage[raw_source] << summary if raw_source.present? && raw_source != tbl
        end

        next unless layer.layer_provider == "cog"

        uri = LayerTableParser.source_from_config(layer)
        if uri.present?
          key = uri.sub(%r{\As3://#{Regexp.escape(bucket)}/}, "").sub(%r{\As3://[^/]+/}, "")
          cog_index[key] << summary
        end

        ab_uri = LayerTableParser.s3_uri_from_analysis_body(layer)
        if ab_uri.present?
          ab_key = ab_uri.sub(%r{\As3://[^/]+/}, "")
          cog_index[ab_key] << summary
        end
      end

      {
        table_usage: table_usage.transform_values { |ls| ls.uniq { |l| l[:id] } },
        cog_index:   cog_index.transform_values   { |ls| ls.uniq { |l| l[:id] } }
      }
    end
  end

  def layer_usage_by_table
    @layer_usage_by_table ||= layer_usage_maps[:table_usage]
  end

  def cog_layer_index
    @cog_layer_index ||= layer_usage_maps[:cog_index]
  end

  def layer_summary(layer)
    {id: layer.id, slug: layer.slug, name: layer.name}
  end

  # ── S3 inventory ─────────────────────────────────────────────────────────────

  # Combines the cached raw S3 listing with the cached COG layer index.
  def fetch_s3_cogs
    raw = fetch_raw_s3_objects
    return nil if raw.nil?

    index = cog_layer_index
    raw.map { |obj| obj.merge(layers: index[obj[:key]] || []) }
  end

  # Returns the raw S3 object list [{key:, size_bytes:}] from cache or live S3.
  # Never writes nil to cache — on S3 error, @s3_error is set on the instance
  # and nil propagates so the caller can surface the error message.
  def fetch_raw_s3_objects
    cached = Rails.cache.read(S3_RAW_CACHE_KEY)
    return cached if cached

    result = list_s3_objects
    Rails.cache.write(S3_RAW_CACHE_KEY, result, expires_in: S3_RAW_TTL) if result
    result
  end

  def list_s3_objects
    bucket = ENV["S3_BUCKET"].presence || "resilienceatlas"
    prefix = ENV["COG_PREFIX"].presence || "cogs/"
    prefix = "#{prefix}/" unless prefix.end_with?("/")

    client = build_s3_client
    results = []
    continuation_token = nil

    loop do
      opts = {bucket: bucket, prefix: prefix, max_keys: 1000}
      opts[:continuation_token] = continuation_token if continuation_token

      resp = client.list_objects_v2(**opts)
      resp.contents.each { |obj| results << {key: obj.key, size_bytes: obj.size} }

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

  def build_s3_client
    Aws::S3::Client.new(
      region: ENV["AWS_REGION"].presence || "us-east-1",
      access_key_id: ENV["AWS_ACCESS_KEY_ID"].presence,
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"].presence
    )
  end
end
