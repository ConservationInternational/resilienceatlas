# frozen_string_literal: true

# Manages PostgreSQL views in the ra_vector schema.
#
# Views in ra_vector can be served as MVT tiles via the generic ra_vector_tile
# function (e.g. /ra_vector_tile/{z}/{x}/{y}?table=v_my_view), which means any
# join between a non-spatial table and an ra_vector geometry table can be
# exposed as a martin layer without requiring a dedicated tile function.
#
# Security model:
#   - View names are validated: lowercase, starts with "v_", max 63 chars,
#     alphanumeric + underscores only.
#   - SQL is validated: must be a bare SELECT (no DML, DDL, or stacked
#     statements).  Table references are allowed only from the three managed
#     schemas (ra_vector, ra_nonspatial, ra_raster).
#   - CREATE OR REPLACE is used inside a transaction that is rolled back if the
#     view does not expose a geometry column (detected via geometry_columns).
class Api::Admin::VectorViewsController < Api::Admin::ApiController
  MANAGED_SCHEMAS = %w[ra_vector ra_nonspatial ra_raster].freeze

  # Naming convention: view names must start with "v_" to be unambiguous.
  VIEW_NAME_RE = /\Av_[a-z][a-z0-9_]{0,60}\z/

  # SQL guard: reject any statement that is not a plain SELECT.
  # We look for DML/DDL keywords at word boundaries after stripping leading
  # whitespace and block comments.
  DANGEROUS_KEYWORDS_RE = /\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|
    EXECUTE|COPY|GRANT|REVOKE|CALL|DO|SET|PERFORM|REFRESH)\b/xi

  # GET /api/admin/vector_views
  # Lists all views in the ra_vector schema (name, geometry column, row count).
  def index
    conn = ActiveRecord::Base.connection

    rows = conn.select_all(<<~SQL).map(&:symbolize_keys)
      SELECT
        c.relname                    AS name,
        gc.f_geometry_column         AS geometry_column,
        gc.type                      AS geometry_type,
        obj_description(c.oid, 'pg_class') AS description
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN geometry_columns gc
        ON gc.f_table_schema = 'ra_vector'
       AND gc.f_table_name   = c.relname
      WHERE n.nspname = 'ra_vector'
        AND c.relkind  = 'v'
        AND c.relname LIKE 'v\\_%'
      ORDER BY c.relname
    SQL

    render json: {success: true, data: rows}, status: :ok
  rescue => e
    render json: {success: false, message: e.message}, status: :internal_server_error
  end

  # POST /api/admin/vector_views
  # Creates (or replaces) a view in ra_vector from a validated SELECT query.
  #
  # Body: { name: "v_my_view", sql: "SELECT ...", description: "optional" }
  def create
    name = params.require(:name)
    sql = validated_select_sql!(params.require(:sql))
    description = params[:description].presence

    validate_view_name!(name)

    conn = ActiveRecord::Base.connection

    conn.transaction do
      conn.execute(create_view_statement(conn, name, sql))

      if description.present?
        conn.execute(
          "COMMENT ON VIEW ra_vector.#{conn.quote_table_name(name)} IS #{conn.quote(description)}"
        )
      end

      # Verify the view exposes a geometry column (required for ra_vector_tile)
      geom = conn.select_value(<<~SQL)
        SELECT f_geometry_column
        FROM geometry_columns
        WHERE f_table_schema = 'ra_vector'
          AND f_table_name   = #{conn.quote(name)}
        LIMIT 1
      SQL

      if geom.nil?
        raise ActiveRecord::Rollback,
          "View '#{name}' does not contain a geometry column. " \
          "Ensure the SELECT includes a geometry column from an ra_vector or ra_nonspatial table."
      end

      render json: {
        success: true,
        data: {name: name, geometry_column: geom, description: description}
      }, status: :ok
    end
  rescue ArgumentError => e
    render json: {success: false, message: e.message}, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    render json: {success: false, message: "SQL error: #{e.message}"}, status: :unprocessable_entity
  rescue => e
    render json: {success: false, message: e.message}, status: :internal_server_error
  end

  # DELETE /api/admin/vector_views/:id   (id = view name)
  def destroy
    name = params[:id]
    validate_view_name!(name)

    conn = ActiveRecord::Base.connection

    unless conn.select_value(<<~SQL)
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'ra_vector' AND c.relname = #{conn.quote(name)} AND c.relkind = 'v'
    SQL
      return render json: {success: false, message: "View '#{name}' not found in ra_vector."}, status: :not_found
    end

    conn.execute("DROP VIEW IF EXISTS ra_vector.#{conn.quote_table_name(name)}")
    render json: {success: true, message: "View '#{name}' dropped."}, status: :ok
  rescue ArgumentError => e
    render json: {success: false, message: e.message}, status: :unprocessable_entity
  rescue => e
    render json: {success: false, message: e.message}, status: :internal_server_error
  end

  private

  def validate_view_name!(name)
    unless VIEW_NAME_RE.match?(name.to_s)
      raise ArgumentError,
        "Invalid view name '#{name}'. Must start with 'v_', be lowercase alphanumeric/underscores, max 63 chars."
    end
  end

  def validate_sql!(sql)
    stripped = sql.to_s.gsub(/\A\s+/, "").gsub(%r{/\*.*?\*/}m, "").strip

    unless stripped.match?(/\ASELECT\b/i)
      raise ArgumentError, "SQL must be a SELECT statement."
    end

    if stripped.include?(";")
      raise ArgumentError, "SQL must not contain semicolons (no stacked statements)."
    end

    if DANGEROUS_KEYWORDS_RE.match?(stripped)
      raise ArgumentError, "SQL contains disallowed keywords. Only SELECT statements are permitted."
    end

    # Check that all FROM/JOIN schema references are in managed schemas
    unmanaged = sql.scan(/\b([a-z_][a-z0-9_]*)\.([a-z_][a-z0-9_]*)\b/i)
      .map(&:first)
      .map(&:downcase)
      .uniq
      .reject { |s| MANAGED_SCHEMAS.include?(s) || s == "ra_vector" }

    if unmanaged.any?
      raise ArgumentError,
        "SQL references unmanaged schemas: #{unmanaged.join(", ")}. " \
        "Only #{MANAGED_SCHEMAS.join(", ")} are allowed."
    end

    stripped
  end

  def validated_select_sql!(sql)
    validate_sql!(sql)
  end

  def create_view_statement(conn, view_name, select_sql)
    "CREATE OR REPLACE VIEW #{conn.quote_table_name("ra_vector")}.#{conn.quote_table_name(view_name)} AS #{select_sql}"
  end
end
