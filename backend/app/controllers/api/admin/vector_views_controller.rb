# frozen_string_literal: true

class Api::Admin::VectorViewsController < Api::Admin::ApiController
  before_action :require_superadmin!

  def index
    rows = ActiveRecord::Base.connection.select_all(<<~SQL)
      SELECT c.relname AS name, gc.f_geometry_column AS geometry_column,
             gc.type AS geometry_type, obj_description(c.oid, 'pg_class') AS description
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN geometry_columns gc
        ON gc.f_table_schema = n.nspname AND gc.f_table_name = c.relname
      WHERE n.nspname = 'ra_vector' AND c.relkind = 'v'
      ORDER BY c.relname
    SQL
    render json: {success: true, data: rows}, status: :ok
  end

  def create
    reject_sql_mutation
  end

  def destroy
    reject_sql_mutation
  end

  private

  def reject_sql_mutation
    Rails.logger.warn "[VectorViews] Rejected SQL view mutation by admin #{@api_admin_user.id}"
    render json: {success: false, message: "SQL view mutations through the API are disabled. Use a reviewed database migration."}, status: :forbidden
  end
end
