# frozen_string_literal: true

# Filter out PostGIS-managed schemas from schema.rb dumps
#
# The "topology" schema is created automatically by the postgis_topology extension.
# Including it in schema.rb causes issues because:
# 1. It conflicts with the extension when running db:schema:load
# 2. It creates unnecessary diffs in schema.rb
#
# This initializer patches the schema dumper to exclude the topology schema.

Rails.application.config.to_prepare do
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper)
    ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.class_eval do
      # Store the original method
      alias_method :original_schemas, :schemas if method_defined?(:schemas)

      # Override schemas to filter out PostGIS-managed schemas
      def schemas(stream)
        # Get all schemas from the database
        schema_names = @connection.query_values(<<~SQL.squish, "SCHEMA")
          SELECT nspname
          FROM pg_namespace
          WHERE nspname !~ '^pg_'
          AND nspname NOT IN ('public', 'information_schema')
          ORDER BY nspname
        SQL

        # Filter out schemas managed by PostGIS extensions
        postgis_managed_schemas = %w[topology]
        filtered_schemas = schema_names - postgis_managed_schemas

        # Only output create_schema for non-PostGIS schemas
        filtered_schemas.each do |schema_name|
          stream.puts "  create_schema #{schema_name.inspect}"
        end
        stream.puts if filtered_schemas.any?
      end
    end
  end
end
