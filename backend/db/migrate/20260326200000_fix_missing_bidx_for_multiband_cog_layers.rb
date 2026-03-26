# Re-run the Trends.Earth seed to fix layers missing bidx.
#
# The seed was originally run before bidx support was added to the layer_config.
# The seed script uses find_or_initialize_by(slug:) so re-running it will update
# existing layers with the correct bidx for each band (1-14).
#
# Without bidx, TiTiler returns 500: {"detail":"Source data must be 1 band"}
class FixMissingBidxForMultibandCogLayers < ActiveRecord::Migration[7.2]
  def up
    seed_file = Rails.root.join("db/data/trendsearth/seed.rb")

    unless File.exist?(seed_file)
      Rails.logger.warn "FixMissingBidx: Seed file not found at #{seed_file}, skipping"
      return
    end

    Rails.logger.info "FixMissingBidx: Re-running Trends.Earth seed to set correct bidx values"
    load seed_file
    Rails.logger.info "FixMissingBidx: Seed completed"
  end

  def down
    # The seed is idempotent; no rollback needed
    Rails.logger.info "FixMissingBidx: Rollback is a no-op"
  end
end
