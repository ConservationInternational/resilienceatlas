# Scans PostgreSQL schemas (ra_vector, ra_raster) and S3 COG objects and
# returns a summary of each asset with the layers that reference it.
#
# Usage:
#   svc = DatasetInventoryService.new
#   svc.vector_tables  # => [{name:, schema:, size_bytes:, row_count:, layers: [...]}]
#   svc.raster_tables  # => same structure
#   svc.s3_cogs        # => [{key:, size_bytes:, layers: [...]}]
class DatasetInventoryService
  VECTOR_SCHEMA = "ra_vector"
  RASTER_SCHEMA = "ra_raster"

  def vector_tables
    pg_tables([VECTOR_SCHEMA]).map do |row|
      row.merge(layers: layers_for_table(row[:name], [VECTOR_SCHEMA]))
    end
  end

  def raster_tables
    pg_tables([RASTER_SCHEMA]).map do |row|
      row.merge(layers: layers_for_table(row[:name], [RASTER_SCHEMA]))
    end
  end

  # Returns nil and sets #s3_error if S3 is not configured or unreachable.
  def s3_cogs
    @s3_cogs ||= fetch_s3_cogs
  end

  attr_reader :s3_error

  private

  def conn
    @conn ||= ActiveRecord::Base.connection
  end

  # ── PostgreSQL inventory ────────────────────────────────────────────────────

  def pg_tables(schemas)
    quoted_schemas = schemas.map { |s| conn.quote(s) }.join(", ")
    rows = conn.execute(<<~SQL)
      SELECT
        t.table_schema,
        t.table_name,
        COALESCE(s.n_live_tup, 0)::bigint                                              AS row_count,
        pg_total_relation_size(
          quote_ident(t.table_schema) || '.' || quote_ident(t.table_name)
        )::bigint                                                                       AS size_bytes
      FROM information_schema.tables t
      LEFT JOIN pg_stat_user_tables s
        ON s.schemaname = t.table_schema AND s.relname = t.table_name
      WHERE t.table_schema IN (#{quoted_schemas})
        AND t.table_type = 'BASE TABLE'
      ORDER BY t.table_schema, t.table_name
    SQL

    rows.map do |r|
      {
        name: r["table_name"],
        schema: r["table_schema"],
        row_count: r["row_count"].to_i,
        size_bytes: r["size_bytes"].to_i
      }
    end
  end

  # Build a map: table_name (bare) => [layer_summary, ...]
  def layer_usage_by_table
    @layer_usage_by_table ||= begin
      usage = Hash.new { |h, k| h[k] = [] }

      Layer.find_each do |layer|
        summary = layer_summary(layer)

        # SQL-based references (query, analysis_query)
        [layer.query, layer.analysis_query].compact.each do |sql|
          LayerTableParser.tables_from_sql(sql).each do |tbl|
            usage[tbl] << summary
          end
        end

        # Martin source (bare table or resolved view)
        if layer.layer_provider == "martin"
          tbl = LayerTableParser.resolve_martin_table(layer, conn)
          usage[tbl] << summary if tbl.present?

          # Also record the view name itself if it differs
          raw_source = LayerTableParser.source_from_config(layer)
          usage[raw_source] << summary if raw_source.present? && raw_source != tbl
        end
      end

      usage.transform_values { |layers| layers.uniq { |l| l[:id] } }
    end
  end

  def layers_for_table(table_name, _schemas)
    layer_usage_by_table[table_name] || []
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
        results << {
          key: obj.key,
          size_bytes: obj.size,
          layers: cog_layers_by_key[obj.key] || []
        }
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

      # Normalise "s3://bucket/key" -> "key"
      key = uri.sub(%r{\As3://#{Regexp.escape(bucket)}/}, "").sub(%r{\As3://[^/]+/}, "")
      index[key] << layer_summary(layer)

      # Also try the analysis_body URL
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
