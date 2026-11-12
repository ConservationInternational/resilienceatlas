require "rails_helper"
require "rake"
require Rails.root.join("lib/tile_security_import_task")

RSpec.describe TileSecurityImportTask do
  let!(:layer) do
    create(:layer, published: false, timeline: false, layer_provider: "cog",
      layer_config: '{"body":{"source":"https://storage.example/old.tif"}}', interaction_config: '{"output":[]}')
  end

  around do |example|
    original = Rake.application
    Rake.application = Rake::Application.new
    example.run
  ensure
    Rake.application = original
  end

  before do
    stub_const("ENV", ENV.to_h.merge("TILE_IMPORT_FINGERPRINT" => "task-manifest-v1", "TILE_IMPORT_IDENTITY" => "operator:task"))
  end

  it "wraps raw update_columns writers and skips an identical manifest rerun" do
    writes = 0
    task = Rake::Task.define_task("test:raw_write") do
      writes += 1
      layer.update_columns(layer_config: '{"body":{"source":"https://storage.example/new.tif"}}')
    end
    described_class.wrap("test:raw_write")
    previous = layer.tile_cache_version
    task.invoke
    expect(layer.reload.tile_cache_version).not_to eq(previous)
    expect(TileSourceImport.last.operation).to eq("test:raw_write")
    task.reenable
    task.invoke
    expect(writes).to eq(1)
  end

  it "does not call the writer or create durable work in dry-run mode" do
    ENV["TILE_IMPORT_DRY_RUN"] = "1"
    task = Rake::Task.define_task("test:raw_write") { raise "must not write" }
    described_class.wrap("test:raw_write")
    expect { task.invoke }.not_to change(TileSourceImport, :count)
  end

  it "refuses an external import without a trustworthy input fingerprint" do
    ENV.delete("TILE_IMPORT_FINGERPRINT")
    task = Rake::Task.define_task("test:raw_write") { raise "must not write" }
    described_class.wrap("test:raw_write")
    expect { task.invoke }.to raise_error(ArgumentError, /TILE_IMPORT_FINGERPRINT/)
  end
end
