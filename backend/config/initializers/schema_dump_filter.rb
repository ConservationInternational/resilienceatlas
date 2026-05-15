# frozen_string_literal: true

# Handle PostGIS-managed and external data schemas in schema.rb.
#
# Schema layout:
#   ra_app    — Rails-managed tables; appears in schema.rb normally
#   ra_vector — externally-managed vector / CartoDB attribute tables
#   ra_raster — externally-managed raster data
#   topology  — created automatically by postgis_topology extension
#
# ra_vector and ra_raster are excluded from schema.rb entirely (both
# create_schema statements and table definitions) because they contain data
# loaded outside Rails migrations.  Their schemas are created by the
# 20260515160000_create_ra_schemas migration.
#
# topology is excluded because postgis_topology creates it automatically,
# so a create_schema call in schema.rb would fail on db:schema:load.
#
# All managed schemas are made idempotent on create_schema so that
# db:schema:load does not fail when run against an existing database.

# Schemas where create_schema must be idempotent on db:schema:load.
# ra_app is created by the 20260515160000_create_ra_schemas migration and appears
# in schema.rb; ra_vector/ra_raster are also migration-created but excluded from
# schema.rb entirely (see below).
IDEMPOTENT_SCHEMAS = %w[topology ra_app ra_vector ra_raster].freeze

# Schemas to omit entirely from schema.rb (create_schema statements + all tables).
# ra_vector and ra_raster hold externally-managed data loaded outside Rails migrations.
# topology is auto-created by the postgis_topology extension.
FILTERED_FROM_DUMP = %w[topology ra_vector ra_raster].freeze

# Module to make create_schema idempotent for all managed schemas
module IdempotentPostgisSchema
  def create_schema(schema_name, *args, **kwargs)
    if IDEMPOTENT_SCHEMAS.include?(schema_name.to_s) && schema_exists?(schema_name)
      return
    end
    super
  end
end

# Patch schema dumper to exclude externally-managed schemas and their tables
module PostgisSchemaFilter
  # Omit create_schema statements for filtered schemas
  def schemas(stream)
    schema_names = @connection.query_values(<<~SQL.squish, "SCHEMA")
      SELECT nspname
      FROM pg_namespace
      WHERE nspname !~ '^pg_'
      AND nspname NOT IN ('public', 'information_schema')
      ORDER BY nspname
    SQL

    filtered_schemas = schema_names - FILTERED_FROM_DUMP

    filtered_schemas.each do |schema_name|
      stream.puts "  create_schema #{schema_name.inspect}"
    end
    stream.puts if filtered_schemas.any?
  end

  # Populate the set of table names that belong to external schemas so that
  # ignored? can exclude them from the table dump.
  def tables(stream)
    @external_schema_tables = @connection.execute(<<~SQL).map { |row| row["relname"] }
      SELECT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind IN ('r', 'p')
        AND n.nspname = ANY(ARRAY['#{FILTERED_FROM_DUMP.join("', '")}'])
    SQL
    super
  end

  def ignored?(table_name)
    @external_schema_tables&.include?(table_name.to_s) || super
  end
end

ActiveSupport.on_load(:active_record) do
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(IdempotentPostgisSchema)
  end

  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper)
    ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(PostgisSchemaFilter)
  end
end
