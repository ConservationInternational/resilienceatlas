require "rails_helper"

RSpec.describe TileByteCache do
  let(:store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    stub_const("ENV", ENV.to_h.merge("TILE_CACHE_REDIS_URL" => "redis://tile-cache-test:6379/0"))
    described_class.reset!
    allow(described_class).to receive(:store).and_return(store)
  end

  it "canonicalizes keys independently of hash insertion order" do
    expect(described_class.key(a: 1, b: {x: 2, y: 3})).to eq(described_class.key(b: {y: 3, x: 2}, a: 1))
  end

  it "reuses successful bounded tile bytes" do
    calls = 0
    render = -> do
      calls += 1
      {status: 200, body: "tile-bytes", content_type: "image/png"}
    end

    expect(described_class.fetch("tile-key", &render)[:body]).to eq("tile-bytes")
    expect(described_class.fetch("tile-key", &render)[:body]).to eq("tile-bytes")
    expect(calls).to eq(1)
    counters = described_class.stats.fetch("counters")
    expect(counters).to include("hits" => 1, "misses" => 1, "writes" => 1, "bytes_written" => 10, "bytes_served" => 10)
  end

  it "does not cache errors, empty bodies, or oversized responses" do
    [
      {status: 403, body: "denied"},
      {status: 200, body: ""},
      {status: 200, body: "x" * (described_class::MAX_BYTES + 1)}
    ].each_with_index do |result, index|
      calls = 0
      2.times do
        described_class.fetch("uncacheable-#{index}") do
          calls += 1
          result
        end
      end
      expect(calls).to eq(2)
    end
  end

  it "bypasses Redis when no dedicated URL is configured" do
    stub_const("ENV", ENV.to_h.except("TILE_CACHE_REDIS_URL"))
    expect(described_class).not_to receive(:store)
    expect(described_class.fetch("tile-key") { {status: 200, body: "tile"} }[:body]).to eq("tile")
    expect(described_class.stats.dig("counters", "disabled_bypasses")).to eq(1)
  end

  it "reports bounded process aggregates without cache keys or invalidation paths" do
    TileCacheInvalidation.create!(paths: ["/api/public-tiles/12/*"], status: "pending")
    TileCacheInvalidation.create!(paths: ["/api/public-tiles/34/*"], status: "completed")

    stats = described_class.stats

    expect(stats).to include(
      "enabled" => true,
      "scope" => "process",
      "capacity" => {
        "max_tile_bytes" => described_class::MAX_BYTES,
        "max_ttl_seconds" => described_class::DEFAULT_TTL,
        "redis_available" => false,
        "redis_used_bytes" => nil,
        "redis_max_bytes" => nil,
        "redis_key_count" => nil
      },
      "invalidations" => {"pending" => 1, "submitted" => 0, "completed" => 1, "failed" => 0}
    )
    expect(stats.to_json).not_to include("public-tiles", "tile-key")
  end

  it "counts Redis read errors without surfacing cache keys" do
    allow(store).to receive(:read).and_raise(IOError, "connection details")

    described_class.fetch("sensitive-key") { {status: 200, body: "tile"} }

    counters = described_class.stats.fetch("counters")
    expect(counters).to include("errors" => 1, "read_errors" => 1, "misses" => 1)
    expect(described_class.stats.to_json).not_to include("sensitive-key", "connection details")
  end
end
