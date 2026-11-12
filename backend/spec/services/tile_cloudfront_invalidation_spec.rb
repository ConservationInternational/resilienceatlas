require "rails_helper"
require "aws-sdk-core"

RSpec.describe TileCloudfrontInvalidation do
  let(:service) { described_class.new }
  let(:endpoint) { "https://cloudfront.amazonaws.com/2020-05-31/distribution/DIST123/invalidation" }

  before do
    stub_const("ENV", ENV.to_h.merge("TILE_CLOUDFRONT_DISTRIBUTION_IDS" => "DIST123"))
    credentials = Aws::Credentials.new("test-access-key", "test-secret-key")
    allow(Aws::CredentialProviderChain).to receive(:new).and_return(instance_double(Aws::CredentialProviderChain, resolve: credentials))
  end

  it "signs an idempotent invalidation against the fixed AWS endpoint" do
    request = stub_request(:post, endpoint)
      .with(headers: {"Authorization" => /AWS4-HMAC-SHA256/},
        body: /<CallerReference>tile-invalidation-1<\/CallerReference>/)
      .to_return(status: 201, body: "<Invalidation><Id>INV123</Id><Status>InProgress</Status></Invalidation>")
    expect(service.submit(["/api/public-tiles/1/*"], "tile-invalidation-1")).to eq("DIST123" => "INV123")
    expect(request).to have_been_requested.once
  end

  it "distinguishes confirmed completion from submission" do
    stub_request(:get, "#{endpoint}/INV123")
      .to_return(status: 200, body: "<Invalidation><Status>InProgress</Status></Invalidation>")
      .then.to_return(status: 200, body: "<Invalidation><Status>Completed</Status></Invalidation>")
    expect(service.completed?("DIST123", "INV123")).to be false
    expect(service.completed?("DIST123", "INV123")).to be true
  end

  it "surfaces malformed or missing completion status" do
    stub_request(:get, "#{endpoint}/INV123").to_return(status: 200, body: "<Invalidation/>")
    expect { service.completed?("DIST123", "INV123") }.to raise_error(described_class::Error, /unknown invalidation status/)
  end

  it "surfaces authorization failures rather than accepting a denied invalidation" do
    stub_request(:post, endpoint).to_return(status: 403, body: "<Error>Denied</Error>")
    expect { service.submit(["/api/public-tiles/1/*"], "test") }.to raise_error(described_class::Error, /HTTP 403/)
  end

  it "rejects path injection in distribution identifiers without a request" do
    expect { service.completed?("../private", "INV123") }.to raise_error(described_class::Error, /Invalid CloudFront identifier/)
    expect(WebMock).not_to have_requested(:get, /cloudfront.amazonaws.com/)
  end
end
