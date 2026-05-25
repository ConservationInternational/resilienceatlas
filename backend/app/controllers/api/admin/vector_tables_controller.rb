# frozen_string_literal: true

class Api::Admin::VectorTablesController < Api::Admin::ApiController
  ALLOWED_EXTENSIONS = %w[.gpkg .geojson .json .kml .zip .shp].freeze
  MANAGED_SCHEMAS = [
    DatasetInventoryService::NONSPATIAL_SCHEMA,
    DatasetInventoryService::VECTOR_SCHEMA,
    DatasetInventoryService::RASTER_SCHEMA
  ].freeze

  # GET /api/admin/vector_tables[?q=keyword]
  # Lists all PostGIS tables in managed schemas with row counts and linked layers.
  def index
    svc = DatasetInventoryService.new
    q = params[:q].presence&.downcase

    rows = [
      svc.nonspatial_tables(per_page: 2000)[:rows],
      svc.vector_tables(per_page: 2000)[:rows],
      svc.raster_tables(per_page: 2000)[:rows]
    ].flatten

    rows.select! { |t| t[:name].to_s.downcase.include?(q) } if q

    data = rows.map do |t|
      {
        name: t[:name],
        schema: t[:schema],
        row_count: t[:row_count],
        size_bytes: t[:size_bytes],
        layers: t[:layers]
      }
    end

    render json: {success: true, data: data}, status: :ok
  rescue StandardError => e
    render json: {success: false, message: e.message}, status: :internal_server_error
  end

  # GET /api/admin/vector_tables/:id   (id = table name)
  # Returns columns (with types), sample rows, and total row count.
  def show
    table_name = params[:id]
    svc = DatasetInventoryService.new

    data = nil
    found_schema = nil
    MANAGED_SCHEMAS.each do |schema|
      result = svc.table_data(schema, table_name, page: 1, per_page: 10)
      if result
        data = result
        found_schema = schema
        break
      end
    end

    unless found_schema
      return render json: {
        success: false,
        message: "Table '#{table_name}' not found in any managed schema (#{MANAGED_SCHEMAS.join(", ")})."
      }, status: :not_found
    end

    conn = ActiveRecord::Base.connection
    col_types = conn.select_all(
      "SELECT column_name, data_type, udt_name " \
      "FROM information_schema.columns " \
      "WHERE table_schema = #{conn.quote(found_schema)} " \
      "  AND table_name   = #{conn.quote(table_name)} " \
      "ORDER BY ordinal_position"
    )
    type_map = col_types.rows.each_with_object({}) do |(col, dtype, udt), h|
      # For user-defined types (e.g. geometry), show udt_name; otherwise show data_type
      h[col] = (dtype == "USER-DEFINED") ? udt : dtype
    end

    render json: {
      success: true,
      data: {
        name: table_name,
        schema: found_schema,
        total_rows: data[:total],
        columns: data[:columns].map { |c| {name: c, type: type_map[c]} },
        sample_rows: data[:rows]
      }
    }, status: :ok
  rescue StandardError => e
    render json: {success: false, message: e.message}, status: :internal_server_error
  end

  # GET /api/admin/vector_tables/:id/statistics?column=col_name[&bins=10]
  # Returns min, max, mean, stddev, null_count, and histogram for a numeric column.
  def statistics
    table_name = params[:id]
    column = params[:column].presence
    bins = params[:bins].to_i
    bins = 10 if bins < 2 || bins > 50

    return render json: {success: false, message: "column is required"}, status: :bad_request unless column

    validate_table_name!(table_name)
    validate_column_name!(column)

    conn = ActiveRecord::Base.connection

    found_schema = MANAGED_SCHEMAS.find do |schema|
      conn.select_value(
        "SELECT 1 FROM information_schema.tables " \
        "WHERE table_schema = #{conn.quote(schema)} AND table_name = #{conn.quote(table_name)} LIMIT 1"
      )
    end

    unless found_schema
      return render json: {success: false, message: "Table '#{table_name}' not found."}, status: :not_found
    end

    col_info = conn.select_one(
      "SELECT data_type FROM information_schema.columns " \
      "WHERE table_schema = #{conn.quote(found_schema)} AND table_name = #{conn.quote(table_name)} " \
      "  AND column_name = #{conn.quote(column)} LIMIT 1"
    )

    unless col_info
      return render json: {
        success: false,
        message: "Column '#{column}' not found in table '#{table_name}'."
      }, status: :not_found
    end

    unless col_info["data_type"]&.match?(/\A(smallint|integer|bigint|numeric|decimal|real|double precision|money)\z/i)
      return render json: {
        success: false,
        message: "Column '#{column}' has type '#{col_info["data_type"]}' which is not numeric."
      }, status: :unprocessable_entity
    end

    quoted_col = quoted_column_name(conn, column)

    stats = conn.select_one(ActiveRecord::Base.sanitize_sql_array([
      <<~SQL,
        SELECT
          MIN(%s::float)    AS min,
          MAX(%s::float)    AS max,
          AVG(%s::float)    AS mean,
          STDDEV(%s::float) AS std,
          COUNT(*)                     AS total_count,
          COUNT(*) FILTER (WHERE %s IS NULL) AS null_count
        FROM %s.%s
      SQL
      Arel.sql(quoted_col),
      Arel.sql(quoted_col),
      Arel.sql(quoted_col),
      Arel.sql(quoted_col),
      Arel.sql(quoted_col),
      Arel.sql(conn.quote_table_name(found_schema)),
      Arel.sql(conn.quote_table_name(table_name))
    ]))

    lo = stats["min"]&.to_f
    hi = stats["max"]&.to_f

    histogram = if lo.nil?
      []
    elsif lo == hi
      [{min: lo, max: hi, count: stats["total_count"].to_i - stats["null_count"].to_i}]
    else
      bucket_width = (hi - lo) / bins
      conn.select_all(ActiveRecord::Base.sanitize_sql_array([
        <<~SQL,
          SELECT
            width_bucket(%s::float, ?, ? , ?) AS bucket,
            COUNT(*) AS cnt
          FROM %s.%s
          WHERE %s IS NOT NULL
          GROUP BY bucket
          ORDER BY bucket
        SQL
        Arel.sql(quoted_col),
        lo,
        hi + 1e-10,
        bins,
        Arel.sql(conn.quote_table_name(found_schema)),
        Arel.sql(conn.quote_table_name(table_name)),
        Arel.sql(quoted_col)
      ])).map do |row|
        b = row["bucket"].to_i
        {min: (lo + (b - 1) * bucket_width).round(6), max: (lo + b * bucket_width).round(6), count: row["cnt"].to_i}
      end
    end

    render json: {
      success: true,
      data: {
        table: table_name,
        schema: found_schema,
        column: column,
        min: lo,
        max: hi,
        mean: stats["mean"]&.to_f,
        std: stats["std"]&.to_f,
        total_count: stats["total_count"].to_i,
        null_count: stats["null_count"].to_i,
        histogram: histogram
      }
    }, status: :ok
  rescue ArgumentError => e
    render json: {success: false, message: e.message}, status: :unprocessable_entity
  rescue StandardError => e
    render json: {success: false, message: e.message}, status: :internal_server_error
  end

  def import
    s3_uri = params.require(:s3_uri)
    table_name = params[:table_name].presence || derive_table_name(s3_uri)

    validate_s3_uri!(s3_uri)
    validate_table_name!(table_name)

    gdal_path = build_gdal_path(s3_uri)
    connection_string = build_pg_connection_string
    pg_env = {"PGPASSWORD" => pg_password}

    stdout, stderr, status = Open3.capture3(
      pg_env,
      "ogr2ogr",
      "-f", "PostgreSQL",
      connection_string,
      gdal_path,
      "-nln", table_name,
      "-overwrite",
      "-t_srs", "EPSG:4326",
      "--config", "GDAL_HTTP_TIMEOUT", "30"
    )

    unless status.success?
      Rails.logger.error("ogr2ogr import failed for #{s3_uri.inspect}: #{stderr.presence || stdout}")
      return render json: {success: false, message: "Vector table import failed. Check server logs for details."}, status: :unprocessable_entity
    end

    result = query_table_metadata(table_name)
    render json: {success: true, data: result}, status: :ok
  rescue ActionController::ParameterMissing => e
    render json: {success: false, message: e.message}, status: :bad_request
  rescue ArgumentError => e
    render json: {success: false, message: e.message}, status: :unprocessable_entity
  end

  private

  def validate_s3_uri!(uri)
    allowed_bucket = ENV.fetch("DATA_BUCKET_NAME", nil)
    unless uri.match?(/\As3:\/\/[a-z0-9][a-z0-9.\-]{1,61}[a-z0-9]\/\S+\z/i)
      raise ArgumentError, "Invalid S3 URI format"
    end
    if allowed_bucket.present? && !uri.start_with?("s3://#{allowed_bucket}/")
      raise ArgumentError, "S3 URI must reference the configured data bucket"
    end
    ext = File.extname(URI.parse(uri.sub("s3://", "https://")).path).downcase
    unless ALLOWED_EXTENSIONS.include?(ext)
      raise ArgumentError, "Unsupported file extension #{ext}. Allowed: #{ALLOWED_EXTENSIONS.join(", ")}"
    end
  end

  def validate_table_name!(name)
    unless name.match?(/\A[a-z][a-z0-9_]{0,62}\z/)
      raise ArgumentError, "table_name must start with a lowercase letter and contain only lowercase letters, digits, and underscores (max 63 chars)"
    end
  end

  def validate_column_name!(name)
    unless name.match?(/\A[a-z_][a-z0-9_]{0,62}\z/)
      raise ArgumentError, "column must start with a lowercase letter or underscore and contain only lowercase letters, digits, and underscores (max 63 chars)"
    end
  end

  def qualified_table_name(conn, schema_name, table_name)
    "#{conn.quote_table_name(schema_name)}.#{conn.quote_table_name(table_name)}"
  end

  def quoted_column_name(conn, column_name)
    conn.quote_column_name(column_name)
  end

  def derive_table_name(s3_uri)
    File.basename(URI.parse(s3_uri.sub("s3://", "https://")).path)
      .sub(/\.[^.]+\z/, "")
      .downcase
      .gsub(/[^a-z0-9]/, "_")
      .gsub(/_{2,}/, "_")
      .gsub(/\A_+|_+\z/, "")
      .then { |n| n.empty? ? "imported_layer" : n }
  end

  def build_gdal_path(s3_uri)
    # Use /vsis3/ so GDAL authenticates via the EC2 instance role;
    # the data bucket does not need a public-read ACL.
    # s3://bucket/key -> /vsis3/bucket/key
    vsis3_path = s3_uri.sub(%r{\As3://}, "/vsis3/")
    ext = File.extname(URI.parse(s3_uri.sub("s3://", "https://")).path).downcase
    case ext
    when ".zip"
      "/vsizip#{vsis3_path}"
    else
      vsis3_path
    end
  end

  def build_pg_connection_string
    cfg = ActiveRecord::Base.connection_db_config.configuration_hash
    host = cfg[:host] || "localhost"
    port = cfg[:port] || 5432
    dbname = cfg[:database]
    user = cfg[:username]
    # Password is passed via PGPASSWORD env var — not included here to keep it out of process argv
    "PG:host=#{host} port=#{port} dbname=#{dbname} user=#{user}"
  end

  def pg_password
    ActiveRecord::Base.connection_db_config.configuration_hash[:password].to_s
  end

  def query_table_metadata(table_name)
    conn = ActiveRecord::Base.connection

    geom_row = conn.exec_query(
      "SELECT type, srid FROM geometry_columns WHERE f_table_name = $1",
      "SQL", [table_name]
    ).first

    # table_name is validated to /\A[a-z][a-z0-9_]{0,62}\z/ — safe to interpolate
    row_count = conn.execute(
      "SELECT COUNT(*) AS n FROM #{conn.quote_table_name(table_name)}"
    ).first["n"].to_i

    excluded_cols = %w[
      ogc_fid the_geom the_geom_webmercator wkb_geometry
      created_at updated_at cartodb_id
    ]
    columns = conn.columns(table_name)
      .reject { |c| excluded_cols.include?(c.name) }
      .map { |c| {name: c.name, type: c.sql_type} }

    {
      table_name: table_name,
      geometry_type: geom_row&.dig("type"),
      srid: geom_row&.dig("srid"),
      row_count: row_count,
      columns: columns
    }
  end
end
