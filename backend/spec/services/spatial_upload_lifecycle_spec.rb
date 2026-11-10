require "rails_helper"

RSpec.describe SpatialUploadLifecycle do
  let(:admin) { create(:admin_user, role: :superadmin) }
  let(:metadata) do
    {"verified" => true, "transferred" => true, "table" => "imported_42_abc",
     "bounds" => [1, 2, 3, 4], "fields" => ["name"],
     "interaction_config" => {"output" => [{"column" => "name", "property" => "Name"}]}}
  end
  let(:di) do
    DataImport.create!(admin_user: admin, import_type: "vector", status: "ready", file_name: "points.geojson",
      metadata: metadata, options: {"workflow" => "spatial_upload", "mode" => "create", "name" => "Points", "slug" => "new-points"})
  end

  before { allow(DatasetInventoryService).to receive(:invalidate_all_caches!) }

  it "creates only one unpublished draft with real provider configuration" do
    lifecycle = described_class.new(di)
    expect { 2.times { lifecycle.finalize! } }.to change(Layer, :count).by(1)
    layer = di.reload.importable
    expect(layer).not_to be_published
    expect(layer.layer_provider).to eq("martin")
    expect(JSON.parse(layer.layer_config).dig("body", "params", "table")).to eq("imported_42_abc")
    expect(JSON.parse(layer.layer_config).dig("body", "styles", "imported_42_abc", "radius")).to eq(5)
  end

  it "preserves layer metadata and compatible style and supports rollback" do
    layer = create(:layer, layer_provider: "martin",
      layer_config: {"body" => {"source" => "old", "colorRamp" => {"property" => "score", "breaks" => [5], "colors" => ["#000000", "#ffffff"]}}}.to_json,
      timeline: false, published: true)
    original = UploadLayerConfiguration.snapshot(layer)
    original_description = layer.description
    di.update!(importable: layer, target_updated_at: layer.updated_at,
      options: di.options.merge("mode" => "replace"), metadata: di.metadata.merge("fields" => ["name", "score"]))
    lifecycle = described_class.new(di)
    lifecycle.finalize!
    expect(layer.reload).to be_published
    expect(layer.description).to eq(original_description)
    expect(JSON.parse(layer.layer_config).dig("body", "colorRamp")).to be_present
    lifecycle.rollback!
    expect(UploadLayerConfiguration.snapshot(layer.reload)).to eq(original)
  end

  it "rejects a stale replacement before changing the live layer" do
    layer = create(:layer)
    di.update!(importable: layer, target_updated_at: layer.updated_at, options: di.options.merge("mode" => "replace"))
    layer.touch
    expect { described_class.new(di).finalize! }.to raise_error(ArgumentError, /layer changed/)
    expect(di.reload).to be_ready
  end

  it "invalidates verification when configuration changes" do
    described_class.new(di).configure!({"color" => "#ff0000"})
    expect(di.reload.metadata).not_to have_key("verified")
  end

  it "requires an explicit style reset if a replacement lacks the color-ramp field" do
    layer = create(:layer, layer_provider: "martin", layer_config: {"body" => {"colorRamp" => {"property" => "missing"}}}.to_json)
    di.update!(importable: layer, options: di.options.merge("mode" => "replace"))
    expect { described_class.new(di).configure!({}) }.to raise_error(ArgumentError, /missing field/)
    expect { described_class.new(di).configure!({"replace_style" => true}) }.not_to raise_error
  end

  it "reprocesses changed ingestion options" do
    described_class.new(di).configure!({"sublayer" => "second"})
    expect(di.reload).to be_needs_input
  end

  it "can finish a standalone dataset without creating a layer" do
    di.update!(options: di.options.merge("mode" => "dataset"))
    expect { described_class.new(di).finalize! }.not_to change(Layer, :count)
    expect(di.reload).to be_complete
  end

  it "validates numeric and JSON display inputs explicitly" do
    [{"rescale" => "10,0"}, {"bidx" => "0"}, {"color" => "red"}].each do |input|
      expect { described_class.new(di).configure!(input) }.to raise_error(ArgumentError)
    end
    expect { described_class.new(di).configure!({"legend" => "not json"}) }.to raise_error(JSON::ParserError)
  end
end
