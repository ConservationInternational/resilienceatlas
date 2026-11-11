require "rails_helper"

RSpec.describe UploadTileService do
  let(:di) do
    DataImport.new(import_type: "cog", options: {"bidx" => "1,2,3"},
      metadata: {"source" => "s3://resilienceatlas/cogs/immutable.tif", "bounds" => [1, 2, 3, 4], "bands" => [{}, {}, {}]})
  end

  before { stub_const("ENV", ENV.to_h.merge("TITILER_URL" => "https://tiler.example.test", "MARTIN_URL" => "http://martin:3000", "DATA_GATEWAY_SECRET" => "test-gateway-secret-32-characters-long")) }

  it "encodes RGB bands as repeated TiTiler query parameters" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return("\x89PNG".b)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    expect(http).to receive(:request) do |request|
      bands = URI.decode_www_form(URI(request.path).query).filter_map { |key, value| value if key == "bidx" }
      expect(bands).to eq(%w[1 2 3])
      expect(request["X-Data-Authorization"]).to match(/\A\d+:[a-f0-9]{64}\z/)
      response
    end
    described_class.new(di).tile(2, 1, 1)
  end

  it "checks both TiTiler metadata and a real PNG response" do
    stub_request(:get, %r{https://tiler.example.test/info}).to_return(body: {"count" => 3}.to_json)
    stub_request(:get, %r{https://tiler.example.test/tiles/}).to_return(body: "not a PNG")
    expect { described_class.new(di).verify! }.to raise_error(IOError, /PNG/)
  end

  it "surfaces upstream errors and invalid coordinates" do
    stub_request(:get, %r{https://tiler.example.test/tiles/}).to_return(status: 503, body: "Unavailable")
    expect { described_class.new(di).tile(2, 1, 1) }.to raise_error(IOError, /503/)
    expect { described_class.new(di).tile(2, 8, 1) }.to raise_error(ArgumentError)
  end
end
