require "rails_helper"

RSpec.describe TileSecurityProbe do
  let!(:scope) { create(:site_scope) }
  let!(:group) { create(:layer_group, site_scope: scope) }
  let!(:layer) { create(:layer, layer_provider: "martin", layer_config: {body: {source: "probe_points"}}.to_json) }
  let!(:actor) { create(:admin_user, role: :admin, allowed_site_scopes: [scope]) }

  before { group.layers << layer }

  def verification
    TileSecurityVerification.create!(layer: layer, admin_user: actor, source_version: TileSecurityPolicy.new(layer.reload).version)
  end

  it "reports missing configured origins instead of a success-shaped fallback" do
    stub_const("ENV", ENV.to_h.except("TILE_PUBLIC_CDN_URL", "TILE_ORIGIN_PROBE_URL"))
    record = verification
    described_class.new(record).call
    expect(record.reload.status).to eq("failed")
    expect(record.results.fetch("error")).to include("Configure")
  end

  it "does not probe arbitrary or insecure origins" do
    stub_const("ENV", ENV.to_h.merge("TILE_PUBLIC_CDN_URL" => "http://127.0.0.1:8080"))
    record = verification
    expect(Net::HTTP).not_to receive(:start)
    described_class.new(record).call
    expect(record.reload.status).to eq("failed")
    expect(record.results.fetch("error")).to include("HTTPS")
  end

  it "rechecks actor permissions before fetching any data" do
    record = verification
    actor.update!(allowed_site_scopes: [])
    expect(Net::HTTP).not_to receive(:start)
    described_class.new(record).call
    expect(record.reload.status).to eq("failed")
  end

  it "marks a changed generation stale before issuing a request" do
    record = verification
    layer.update_column(:tile_cache_version, SecureRandom.hex(16))
    expect(Net::HTTP).not_to receive(:start)
    described_class.new(record).call
    expect(record.reload.status).to eq("stale")
  end

  it "rate limits verification requests in the database" do
    verification
    expect { described_class.request!(layer, actor) }.to raise_error(ArgumentError, /Wait/)
  end

  context "with a configured eligible public route" do
    let(:origin) { "https://tiles.example.com" }
    let(:url) { "#{origin}/api/public-tiles/#{layer.id}/#{layer.reload.tile_cache_version}/0/0/0" }

    before do
      stub_const("ENV", ENV.to_h.except("TILE_ORIGIN_PROBE_URL").merge("TILE_PUBLIC_CDN_URL" => origin))
      policy = instance_double(TileSecurityPolicy, version: layer.reload.tile_cache_version, public_cache_eligible?: true)
      allow(TileSecurityPolicy).to receive(:new).with(layer).and_return(policy)
    end

    it "checks actual image bytes and records anonymous cache evidence" do
      stub_request(:get, url).to_return(status: 200, body: File.binread(Rails.root.join("spec/fixtures/files/picture.jpg")),
        headers: {"Content-Type" => "image/jpeg", "X-Cache" => "Hit from cloudfront"})
      record = verification
      described_class.new(record).call
      expect(record.reload.status).to eq("passed")
      expect(record.results.fetch("cdn")).to include("cache" => "Hit from cloudfront", "expected" => "public_tile")
      expect(WebMock).to have_requested(:get, url).with { |request| request.headers["Authorization"].nil? }
    end

    it "rejects mislabeled error pages rather than reporting public rendering success" do
      stub_request(:get, url).to_return(status: 200, body: "<html>upstream unavailable</html>", headers: {"Content-Type" => "image/png"})
      record = verification
      described_class.new(record).call
      expect(record.reload.status).to eq("failed")
    end

    it "does not follow a redirect to an arbitrary upstream" do
      stub_request(:get, url).to_return(status: 302, headers: {"Location" => "https://untrusted.example.com"})
      record = verification
      described_class.new(record).call
      expect(record.reload.status).to eq("failed")
      expect(WebMock).not_to have_requested(:get, "https://untrusted.example.com")
    end
  end
end

RSpec.describe ArcgisAdminCredentials do
  let!(:layer) do
    create(:layer, layer_provider: "arcgis_feature",
      layer_config: {body: {url: "https://services.arcgis.com/test/FeatureServer/0", token: "stored-secret"}}.to_json)
  end

  it "preserves a masked credential only for the same source" do
    layer.layer_config = {body: {url: "https://services.arcgis.com/test/FeatureServer/0", useProxy: true}}.to_json
    described_class.apply(layer, replacement: nil, clear: false)
    expect(JSON.parse(layer.layer_config).dig("body", "token")).to eq("stored-secret")
    expect(layer.layer_config).not_to include("useProxy")
  end

  it "does not copy credentials to another upstream" do
    layer.layer_config = {body: {url: "https://services.arcgis.com/other/FeatureServer/0"}}.to_json
    described_class.apply(layer, replacement: nil, clear: false)
    expect(JSON.parse(layer.layer_config).dig("body", "token")).to be_nil
  end

  it "supports deliberate credential replacement and removal" do
    described_class.apply(layer, replacement: "new-secret", clear: false)
    expect(JSON.parse(layer.layer_config).dig("body", "token")).to eq("new-secret")
    described_class.apply(layer, replacement: nil, clear: true)
    expect(JSON.parse(layer.layer_config).dig("body", "token")).to be_nil
  end
end
