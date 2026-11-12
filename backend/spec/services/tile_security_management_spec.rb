require "rails_helper"

RSpec.describe TileSecurityManagement do
  let!(:scope) { create(:site_scope) }
  let!(:group) { create(:layer_group, site_scope: scope) }
  let!(:layer) { create(:layer, layer_provider: "martin", layer_config: {body: {source: "management_test_points"}}.to_json) }
  let!(:admin) { create(:admin_user, role: :admin, allowed_site_scopes: [scope]) }
  let!(:superadmin) { create(:admin_user, role: :superadmin) }

  before { group.layers << layer }

  it "requires superadmin authority and rationale for exposure overrides" do
    expect { described_class.new(admin).set_policy!(layer, policy: "restricted", reason: "Confidential") }.to raise_error(CanCan::AccessDenied)
    expect { described_class.new(superadmin).set_policy!(layer, policy: "restricted", reason: "") }.to raise_error(ArgumentError)
  end

  it "records a redacted audit event with explicit restriction" do
    described_class.new(superadmin).set_policy!(layer, policy: "restricted", reason: "Confidential data")
    expect(layer.reload.data_policy).to eq("restricted")
    expect(layer.public_data).to be false
    event = TileSecurityEvent.where(layer: layer, action: "set_policy").last
    expect(event.admin_user).to eq(superadmin)
    expect(event.details).to include("after" => "restricted")
    expect(event.details.to_json).not_to include("management_test_points")
  end

  it "does not grant access when requesting a review" do
    layer.update!(data_policy: "restricted", public_data: false)
    review = described_class.new(admin).request_review!(layer, reason: "Review public release")
    expect(review.status).to eq("pending")
    expect(layer.reload.data_policy).to eq("restricted")
  end

  it "allows publication of external providers without claiming live readiness" do
    layer.update!(published: false, layer_provider: "wmts",
      layer_config: {source: {tiles: ["https://example.com/tiles/{z}/{x}/{y}.png"]}}.to_json)
    described_class.new(admin).publish!(layer)
    expect(layer.reload).to be_published
    expect(TileSecurityPolicy.new(layer).report.fetch("status")).not_to eq("ready")
  end

  it "rejects publication without a scope assignment" do
    group.layers.delete(layer)
    layer.update!(published: false)
    expect { described_class.new(superadmin).publish!(layer) }.to raise_error(ArgumentError, /no_scope_assignment/)
    expect(layer.reload).not_to be_published
  end

  it "denies contributor review writes and cross-scope requests" do
    contributor = create(:admin_user, role: :contributor, allowed_site_scopes: [scope])
    unrelated = create(:admin_user, role: :admin)
    [contributor, unrelated].each do |actor|
      expect { described_class.new(actor).request_review!(layer, reason: "Review") }.to raise_error(CanCan::AccessDenied)
    end
  end

  it "marks a changed-source review stale without approving it" do
    review = described_class.new(admin).request_review!(layer, reason: "Public release")
    layer.update!(tile_cache_version: SecureRandom.hex(16))
    described_class.new(superadmin).resolve_review!(review, approve: true, reason: "Reviewed")
    expect(review.reload.status).to eq("stale")
  end

  it "resolves a current review and records the decision" do
    layer.update!(data_policy: "restricted", public_data: false)
    review = described_class.new(admin).request_review!(layer, reason: "Public release")
    described_class.new(superadmin).resolve_review!(review, approve: true, reason: "Safe for release")
    expect(review.reload.status).to eq("approved")
    expect(layer.reload.data_policy).to eq("public")
    expect(TileSecurityEvent.where(layer: layer, action: "resolve_review")).to exist
  end
end

RSpec.describe TileCacheInvalidation do
  it "rejects empty or non-absolute invalidation paths" do
    expect(described_class.new(paths: []).valid?).to be false
    expect(described_class.new(paths: ["relative"]).valid?).to be false
    expect(described_class.new(paths: ["/api/public-tiles/1/*"]).valid?).to be true
  end

  it "does not claim completion without configured CDN integration" do
    stub_const("ENV", ENV.to_h.except("TILE_CLOUDFRONT_DISTRIBUTION_IDS"))
    record = described_class.create!(paths: ["/api/public-tiles/1/*"])
    expect { record.submit! }.to raise_error(TileCloudfrontInvalidation::Error, /not configured/)
    expect(record.reload.status).to eq("failed")
  end

  it "persists submission and polls completion instead of resubmitting" do
    record = described_class.create!(paths: ["/api/public-tiles/1/*"])
    service = instance_double(TileCloudfrontInvalidation)
    allow(TileCloudfrontInvalidation).to receive(:new).and_return(service)
    expect(service).to receive(:submit).once.and_return({"DIST" => "INV"})
    expect(service).to receive(:completed?).with("DIST", "INV").and_return(false, true)
    record.submit!
    expect(record.reload.status).to eq("submitted")
    record.submit!
    expect(record.reload.status).to eq("completed")
  end
end
