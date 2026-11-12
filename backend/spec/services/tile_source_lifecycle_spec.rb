require "rails_helper"

RSpec.describe TileSourceLifecycle do
  let(:layer) do
    create(:layer, layer_provider: "cog", timeline: false, published: false,
      layer_config: '{"body":{"source":"https://storage.example/immutable.tif"}}', interaction_config: '{"output":[]}')
  end
  let(:arguments) { {operation: "test:import", fingerprint: "manifest-sha256-v1", identity: "operator:test", layers: [layer]} }

  it "plans without writes and reports only digests and record identifiers" do
    expect { described_class.run!(**arguments, dry_run: true) { raise "not called" } }.not_to change(TileSourceImport, :count)
    expect(described_class.new(**arguments).plan.to_json).not_to include("storage.example")
  end

  it "activates new data with a durable identity and idempotent fingerprint" do
    old = layer.tile_cache_version
    described_class.run!(**arguments) { layer.update!(opacity: 0.5) }
    expect(layer.reload.tile_cache_version).not_to eq(old)
    record = TileSourceImport.last
    expect(record.status).to eq("completed")
    expect(record.identity).to eq("operator:test")
    version = layer.tile_cache_version
    expect(described_class.run!(**arguments) { raise "must not run twice" }["unchanged"]).to be(true)
    expect(layer.reload.tile_cache_version).to eq(version)
  end

  it "holds a durable source block through external writer failure" do
    expect { described_class.run!(**arguments) { raise "private details" } }.to raise_error("private details")
    record = TileSourceImport.last
    expect(record.status).to eq("reconciliation_required")
    expect(record.error_message).to eq("RuntimeError")
    expect(TileSecurityPolicy.new(layer).report["reasons"]).to include("source_import_in_progress")
    expect { TileSourceReconciliationJob.new.perform(record.id) }.to raise_error(described_class::ImportBlocked, /writer/)
  end

  it "refuses an overlapping source writer, including aliases" do
    described_class.new(**arguments).stage!
    expect { described_class.run!(**arguments.merge(operation: "different", fingerprint: "new")) {} }
      .to raise_error(described_class::ImportBlocked)
  end

  it "requires all public invalidations to be completed before in-place writes" do
    create(:agrupation, layer: layer, layer_group: create(:layer_group))
    layer.update!(published: true)
    ran = false
    expect { described_class.run!(**arguments) { ran = true } }.to raise_error(described_class::InvalidationPending)
    expect(ran).to be(false)
    record = TileSourceImport.last
    expect(record.status).to eq("invalidation_pending")
    expect(TileCacheInvalidation.where(id: record.invalidation_ids).first.paths).to include("/api/layers*", "/api/layer_groups*")
    TileCacheInvalidation.where(id: record.invalidation_ids).update_all(status: "completed")
    described_class.run!(**arguments) { ran = true }
    expect(ran).to be(true)
    expect(record.reload.status).to eq("completed")
  end

  it "does not treat submitted or failed invalidations as confirmed" do
    layer.update!(published: true)
    create(:agrupation, layer: layer, layer_group: create(:layer_group))
    lifecycle = described_class.new(**arguments)
    record = lifecycle.stage!
    TileCacheInvalidation.where(id: record.invalidation_ids).update_all(status: "submitted")
    expect { lifecycle.ready_to_write! }.to raise_error(described_class::InvalidationPending)
  end

  it "rotates generation when a trusted dependency manifest changes" do
    described_class.run!(**arguments) {}
    old = layer.reload.tile_cache_version
    described_class.run!(**arguments.merge(fingerprint: "changed-view-dependency")) {}
    expect(layer.reload.tile_cache_version).not_to eq(old)
  end

  it "blocks cache eligibility during immutable source activation as well" do
    described_class.run!(**arguments.merge(in_place: false)) do
      expect(TileSecurityPolicy.new(layer).report["reasons"]).to include("source_import_in_progress")
    end
    expect(TileSourceImport.last.status).to eq("completed")
  end

  it "blocks actual public Martin bytes before writes and activates changed bytes under a fresh generation" do
    connection = Layer.connection
    connection.execute("CREATE TABLE ra_vector.lifecycle_points (name text, geom geometry(Point,4326))")
    connection.execute("INSERT INTO ra_vector.lifecycle_points VALUES ('before', ST_SetSRID(ST_Point(0,0),4326))")
    vector = create(:layer, published: true, timeline: false, layer_provider: "martin",
      layer_config: '{"body":{"source":"ra_vector_tile","params":{"table":"lifecycle_points"}}}', interaction_config: '{"output":[]}')
    create(:agrupation, layer: vector, layer_group: create(:layer_group))
    vector.reload
    tile = "SELECT public.ra_vector_tile(0,0,0,'{\"table\":\"lifecycle_points\"}'::json)"
    old_bytes = connection.select_value(tile)
    old_version = vector.tile_cache_version
    expect(old_bytes.bytesize).to be > 0
    lifecycle = described_class.new(**arguments.merge(layers: [vector], operation: "test:vector"))
    record = lifecycle.stage!
    expect {
      connection.transaction(requires_new: true) { connection.select_value(tile) }
    }.to raise_error(ActiveRecord::StatementInvalid, /not approved/)
    expect { lifecycle.ready_to_write! }.to raise_error(described_class::InvalidationPending)
    expect(connection.select_value("SELECT name FROM ra_vector.lifecycle_points")).to eq("before")
    TileCacheInvalidation.where(id: record.invalidation_ids).update_all(status: "completed")
    lifecycle.run! { connection.execute("UPDATE ra_vector.lifecycle_points SET name = 'after'") }
    expect(connection.select_value(tile)).not_to eq(old_bytes)
    expect(vector.reload.tile_cache_version).not_to eq(old_version)
    generation = TileSourceGeneration.find_by!(source_key: TileSecurityPolicy.new(vector).source_key)
    expect(generation.fingerprint).to eq(arguments[:fingerprint])
    restricted_alias = create(:layer, published: false, timeline: false, layer_provider: "martin",
      data_policy: "restricted", layer_config: vector.layer_config, interaction_config: '{"output":[]}')
    expect {
      connection.transaction(requires_new: true) { connection.select_value(tile) }
    }.to raise_error(ActiveRecord::StatementInvalid, /not approved/)
    restricted_alias.destroy!
    expect(connection.select_value(tile).bytesize).to be > 0
    vector.reload.update!(public_data: false)
    expect {
      connection.transaction(requires_new: true) { connection.select_value(tile) }
    }.to raise_error(ActiveRecord::StatementInvalid, /not approved/)
  end

  it "does not reuse a successful writer marker after a failed retry" do
    lifecycle = described_class.new(**arguments)
    record = lifecycle.stage!
    record.update!(status: "reconciliation_required", summary: record.summary.merge("writer_completed" => true))
    expect { lifecycle.run! { raise "retry partially wrote" } }.to raise_error("retry partially wrote")
    expect(record.reload.summary["writer_completed"]).to be(false)
    expect { described_class.resume(record).reconcile! }.to raise_error(described_class::ImportBlocked, /writer/)
  end

  it "does not permit two same-manifest writers to claim one staged import" do
    first = described_class.new(**arguments)
    record = first.stage!
    second = described_class.new(**arguments)
    second.stage!
    first.ready_to_write!
    expect { second.run! { raise "must not run" } }.to raise_error(described_class::ImportBlocked, /active writer/)
    expect { described_class.resume(record.reload).reconcile! }.to raise_error(described_class::ImportBlocked, /writer/)
    expect(record.reload.status).to eq("writing")
  end

  it "exposes only the latest relevant redacted import status" do
    record = described_class.new(**arguments).stage!
    record.update!(summary: record.summary.merge("secret" => "not-for-admin"), error_message: "private details")
    TileSourceImport.create!(run_id: SecureRandom.uuid, operation: "unrelated", fingerprint: "other",
      identity: "operator:other", layer_ids: [layer.id + 1000], status: "completed")
    expect(TileSourceImport.latest_for(layer)).to eq(record)
    expect(record.safe_status.to_json).not_to include("not-for-admin", "private details", "storage.example", "operator:test")
    global = TileSourceImport.create!(run_id: SecureRandom.uuid, operation: "global", fingerprint: "global",
      identity: "operator:global", global: true)
    expect(TileSourceImport.latest_for(layer)).to eq(global)
  end
end
