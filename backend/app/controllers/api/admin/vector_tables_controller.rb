# frozen_string_literal: true

class Api::Admin::VectorTablesController < Api::Admin::ApiController
  ALLOWED_EXTENSIONS = %w[.gpkg .geojson .json .kml .zip .shp].freeze

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

    excluded_cols = %w[ogc_fid the_geom the_geom_webmercator wkb_geometry
                       created_at updated_at cartodb_id]
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
