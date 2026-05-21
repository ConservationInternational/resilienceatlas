# Migrates existing martin layers that use a direct ra_vector table as their
# source to use the new ra_vector_tile function source instead.
#
# Before: layer_config = '{"body":{"source":"imported_slug"}}'
# After:  layer_config = '{"body":{"source":"ra_vector_tile","params":{"table":"imported_slug"}}}'
#
# Only layers whose current source name matches a real base table in the
# ra_vector schema are migrated, leaving all other martin layers (function
# sources, scope_dataset_tiles, etc.) untouched.
class MigrateMartinLayersToFunctionSource < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE layers
      SET layer_config = (
        -- Replace body.source with "ra_vector_tile" and add body.params.table
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
        AND EXISTS (
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector'
            AND c.relname = layer_config::jsonb #>> '{body,source}'
            AND c.relkind = 'r'
        )
    SQL
  end

  def down
    execute <<~SQL
      UPDATE layers
      SET layer_config = (
        -- Restore body.source to the original table name and remove body.params
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
    SQL
  end
end
