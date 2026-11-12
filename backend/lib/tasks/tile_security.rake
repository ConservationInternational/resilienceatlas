namespace :tile_security do
  desc "Read-only grandfather migration inventory; works before or after core migration"
  task migration_inventory: :environment do
    puts JSON.pretty_generate(TileSecurityMigrationInventory.call)
  end

  desc "Stage a host import (TILE_IMPORT_OPERATION and TILE_IMPORT_FINGERPRINT required)"
  task stage: :environment do
    lifecycle = TileSourceLifecycle.new(operation: ENV.fetch("TILE_IMPORT_OPERATION"),
      fingerprint: ENV.fetch("TILE_IMPORT_FINGERPRINT"), identity: TileSourceLifecycle.operator_identity,
      layers: Layer.all, in_place: true, global: true)
    if ENV["TILE_IMPORT_DRY_RUN"] == "1"
      puts JSON.generate(lifecycle.plan)
    else
      record = lifecycle.stage!
      puts "TILE_IMPORT_RUN_ID=#{record.run_id}"
      puts "TILE_IMPORT_STATUS=#{record.status}"
    end
  end

  desc "Check confirmed invalidations and permit an already staged host writer"
  task begin_write: :environment do
    record = TileSourceImport.find_by!(run_id: ENV.fetch("TILE_IMPORT_RUN_ID"))
    raise TileSourceLifecycle::ImportBlocked, "Import identity mismatch" unless record.identity == TileSourceLifecycle.operator_identity
    TileSourceLifecycle.resume(record).ready_to_write!
  end

  desc "Validate and activate a host import after every external writer succeeded"
  task complete: :environment do
    record = TileSourceLifecycle.authorize_enclosing_import!
    record.update!(summary: record.summary.merge("writer_completed" => true), status: "validating")
    puts JSON.generate(TileSourceLifecycle.resume(record).reconcile!)
  end
end
