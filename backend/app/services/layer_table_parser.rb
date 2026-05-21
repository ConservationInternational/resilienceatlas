# Extracts PostGIS table names and S3 URIs from Layer record fields.
# Extracted from CartodbRakeHelpers so it can be reused by the dataset
# inventory service and future tooling.
#
# Usage:
#   LayerTableParser.tables_from_sql(sql)      # => ["my_table", "other_table"]
#   LayerTableParser.source_from_config(layer) # => "my_vector_table" or "s3://..."
#   LayerTableParser.s3_uri_from_config(layer) # => "s3://..." or nil
class LayerTableParser
  # SQL stop-words that are not table names.
  SQL_STOP_WORDS = %w[
    select where and or not in exists between like null is as on using
    true false set update delete insert into values from join inner
    left right outer full cross natural lateral case when then else end
    distinct all having group order by limit offset fetch rows only
    with recursive union intersect except
  ].freeze

  # Parses FROM/JOIN clauses in a SQL string and returns bare table names.
  # Excludes CTEs and SQL stop-words.
  def self.tables_from_sql(sql)
    return [] if sql.blank?

    # Collect CTE names so they are not reported as physical tables
    cte_names = sql.scan(/\bWITH\s+(\w+)\s+AS\s*\(/i).flatten.map(&:downcase)

    tables = []

    # FROM and JOIN clauses
    sql.scan(/\b(?:FROM|JOIN)\s+([\w."]+)/i) do |match|
      raw = match[0].delete('"').split(".").last.downcase
      next if SQL_STOP_WORDS.include?(raw)
      next if cte_names.include?(raw)
      tables << raw
    end

    tables.uniq
  end

  # Returns the Martin source (bare table name) or COG S3 URI from layer_config.
  # Returns nil for other provider types.
  def self.source_from_config(layer)
    return nil if layer.layer_config.blank?
    cfg = JSON.parse(layer.layer_config)
    cfg.dig("body", "source")
  rescue JSON::ParserError
    nil
  end

  # Returns the S3 URI from analysis_body.url, or nil.
  def self.s3_uri_from_analysis_body(layer)
    return nil if layer.analysis_body.blank?
    cfg = JSON.parse(layer.analysis_body)
    url = cfg["url"]
    url&.start_with?("s3://") ? url : nil
  rescue JSON::ParserError
    nil
  end

  # Returns the underlying table name for a Martin layer source.
  # Handles both direct table names and v_layer_NNN view names.
  # For views, first checks layer_config.cartodb_migration.primary_table,
  # then falls back to inspecting the view definition in PostgreSQL.
  def self.resolve_martin_table(layer, conn = ActiveRecord::Base.connection)
    source = source_from_config(layer)
    return nil if source.blank?
    return nil if source.start_with?("s3://")

    # Not a view pattern — return as-is
    return source unless source.match?(/\Av_layer_\d+\z/)

    # Try cartodb_migration metadata first (cheapest)
    begin
      cfg = JSON.parse(layer.layer_config)
      primary = cfg.dig("cartodb_migration", "primary_table").to_s.strip
      return primary if primary.present?
    rescue JSON::ParserError
      nil
    end

    # Fall back to pg_views
    view_def = conn.select_value(
      "SELECT definition FROM pg_views " \
      "WHERE schemaname = 'ra_vector' AND viewname = #{conn.quote(source)}"
    ).to_s
    tables_from_sql(view_def).first
  rescue => e
    Rails.logger.warn "LayerTableParser.resolve_martin_table(#{layer.id}): #{e.message}"
    source # return the view name unchanged rather than nil
  end
end
