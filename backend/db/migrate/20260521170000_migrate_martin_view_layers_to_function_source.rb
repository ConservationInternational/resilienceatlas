# Migrates martin layers whose source is an ra_vector VIEW (not a plain table)
# to use the ra_vector_tile function source, just like
# 20260520130000_migrate_martin_layers_to_function_source.rb did for plain tables.
#
# The original migration only checked relkind = 'r' (ordinary table), so layers
# backed by views (relkind = 'v') such as the DHS layers (v_layer_*) were left
# pointing at a non-existent direct Martin source, producing 404 tile responses.
#
# Before: layer_config = '{"body":{"source":"v_layer_20"}}'
# After:  layer_config = '{"body":{"source":"ra_vector_tile","params":{"table":"v_layer_20"}}}'
#
# Only layers whose current source name matches a view or materialized view in
# ra_vector are migrated.  Plain-table layers already migrated by 20260520130000,
# and other special sources (scope_dataset_tiles, etc.) are left untouched.
class MigrateMartinViewLayersToFunctionSource < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE layers
      SET layer_config = (
        jsonb_set(
          jsonb_set(
            layer_config::jsonb,
            '{body,source}',
            '"ra_vector_tile"'
          ),
          '{body,params}',
          jsonb_build_object('table', layer_config::jsonb #>> '{body,source}')
        )
      )::text
      WHERE layer_provider = 'martin'
        AND layer_config::jsonb #>> '{body,source}' != 'ra_vector_tile'
        AND EXISTS (
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector'
            AND c.relname = layer_config::jsonb #>> '{body,source}'
            AND c.relkind IN ('v', 'm')
        )
    SQL
  end

  def down
    execute <<~SQL
      UPDATE layers
      SET layer_config = (
        (layer_config::jsonb - 'body') ||
        jsonb_build_object(
          'body',
          (((layer_config::jsonb -> 'body') - 'params') - 'source') ||
          jsonb_build_object('source', layer_config::jsonb #>> '{body,params,table}')
        )
      )::text
      WHERE layer_provider = 'martin'
        AND layer_config::jsonb #>> '{body,source}'       = 'ra_vector_tile'
        AND layer_config::jsonb #>> '{body,params,table}' IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector'
            AND c.relname = layer_config::jsonb #>> '{body,params,table}'
            AND c.relkind IN ('v', 'm')
        )
    SQL
  end
end
