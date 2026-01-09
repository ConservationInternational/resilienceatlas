# frozen_string_literal: true

# Handle PostGIS-managed schemas in schema.rb
#
# The "topology" schema is created automatically by the postgis_topology extension.
# This causes two issues:
# 1. Schema dump: topology appears in schema.rb unnecessarily
# 2. Schema load: create_schema "topology" fails because the extension already created it
#
# This initializer:
# - Filters topology from schema dumps (prevents future occurrences)
# - Makes create_schema idempotent for topology (handles existing schema.rb files)

POSTGIS_MANAGED_SCHEMAS = %w[topology].freeze

# Module to make create_schema idempotent for PostGIS-managed schemas
module IdempotentPostgisSchema
  def create_schema(schema_name, *args, **kwargs)
    # Skip creation for PostGIS-managed schemas if they already exist
    if POSTGIS_MANAGED_SCHEMAS.include?(schema_name.to_s) && schema_exists?(schema_name)
      return
    end
    super
  end
end

# Patch schema dumper to exclude PostGIS-managed schemas
module PostgisSchemaFilter
  def schemas(stream)
    schema_names = @connection.query_values(<<~SQL.squish, "SCHEMA")
      SELECT nspname
      FROM pg_namespace
      WHERE nspname !~ '^pg_'
      AND nspname NOT IN ('public', 'information_schema')
      ORDER BY nspname
    SQL

    filtered_schemas = schema_names - POSTGIS_MANAGED_SCHEMAS

    filtered_schemas.each do |schema_name|
      stream.puts "  create_schema #{schema_name.inspect}"
    end
    stream.puts if filtered_schemas.any?
  end
end

ActiveSupport.on_load(:active_record) do
  # Prepend idempotent schema handling to the PostgreSQL adapter
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(IdempotentPostgisSchema)
  end

  # Prepend schema filter to the schema dumper
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper)
    ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(PostgisSchemaFilter)
  end
end
