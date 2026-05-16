# Fix COG layer source URLs to use s3:// scheme instead of HTTPS
#
# The original migration (20260119160000) accidentally stored HTTPS URLs like:
#   https://resilienceatlas.s3.dualstack.us-east-1.amazonaws.com/cogs/layer.tif
#
# These are accessed by GDAL via VSICURL (anonymous HTTP). If the resilienceatlas
# S3 bucket is not publicly readable, GDAL gets a 403 → RasterioIOError → 500.
#
# The correct format is the s3:// scheme:
#   s3://resilienceatlas/cogs/layer.tif
#
# GDAL's /vsis3/ driver maps s3:// URLs to S3 API calls using the Lambda IAM role
# (which has S3ReadPolicy for the resilienceatlas bucket as of this migration).
#
class FixCogSourceUrlsToS3Scheme < ActiveRecord::Migration[7.2]
  HTTPS_PREFIX = "https://resilienceatlas.s3.dualstack.us-east-1.amazonaws.com/cogs/".freeze
  S3_PREFIX = "s3://resilienceatlas/cogs/".freeze

  def up
    # Replace HTTPS S3 URLs with s3:// scheme in layer_config.body.source
    # so GDAL uses IAM credentials (Lambda execution role) instead of anonymous HTTP
    execute(<<-SQL.squish)
      UPDATE layers
      SET layer_config = jsonb_set(
        layer_config,
        '{body,source}',
        to_jsonb(replace(layer_config->'body'->>'source', '#{HTTPS_PREFIX}', '#{S3_PREFIX}'))
      )
      WHERE layer_provider = 'cog'
      AND layer_config->'body'->>'source' LIKE '#{HTTPS_PREFIX}%'
    SQL

    updated = execute("SELECT COUNT(*) FROM layers WHERE layer_provider = 'cog' AND layer_config->'body'->>'source' LIKE '#{S3_PREFIX}%'").first["count"]
    Rails.logger.info "FixCogSourceUrlsToS3Scheme: Updated #{updated} COG layer(s) to s3:// source URL scheme"
  end

  def down
    # Restore HTTPS URLs from s3:// scheme
    execute(<<-SQL.squish)
      UPDATE layers
      SET layer_config = jsonb_set(
        layer_config,
        '{body,source}',
        to_jsonb(replace(layer_config->'body'->>'source', '#{S3_PREFIX}', '#{HTTPS_PREFIX}'))
      )
      WHERE layer_provider = 'cog'
      AND layer_config->'body'->>'source' LIKE '#{S3_PREFIX}%'
    SQL
  end
end
