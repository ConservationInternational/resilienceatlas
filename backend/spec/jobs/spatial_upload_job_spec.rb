require "rails_helper"

RSpec.describe SpatialUploadJob do
  let(:admin) { create(:admin_user, role: :superadmin) }
  let(:di) do
    DataImport.create!(admin_user: admin, file_name: "points.geojson", file_size_bytes: 2,
      s3_key: "staging/points.geojson", import_type: "vector", status: "pending",
      options: {"workflow" => "spatial_upload", "mode" => "dataset"}, metadata: {"transferred" => true})
  end
  let(:storage) { instance_double(UploadStorage) }
  let(:processor) { instance_double(VectorUploadProcessor) }

  before do
    allow(UploadStorage).to receive(:new).and_return(storage)
    allow(storage).to receive(:download) { |_key, path| File.write(path, "{}") }
    allow(VectorUploadProcessor).to receive(:new).and_return(processor)
    allow(processor).to receive(:call).and_return("table" => "imported_1_abc", "rows" => 1, "bounds" => [1, 2, 3, 4])
  end

  it "processes once and retains transfer identity for retries" do
    2.times { described_class.new.perform(di.id) }
    expect(processor).to have_received(:call).once
    expect(di.reload).to be_ready
    expect(di.metadata["transferred"]).to be(true)
    expect(di.attempts).to eq(1)
  end

  it "persists actionable sublayer selection" do
    allow(processor).to receive(:call).and_raise(UploadSelectionRequired.new("Choose sublayer", {"sublayers" => %w[a b]}))
    described_class.new.perform(di.id)
    expect(di.reload).to be_needs_input
    expect(di.metadata).to include("transferred" => true, "sublayers" => %w[a b])
  end

  it "does not resurrect a cancelled import after the processor returns" do
    allow(processor).to receive(:call) do
      di.update!(status: "cancelled")
      {"table" => "orphan-retained-for-cleanup"}
    end
    described_class.new.perform(di.id)
    expect(di.reload).to be_cancelled
  end

  it "records corrupt-file failures explicitly" do
    allow(processor).to receive(:call).and_raise(ArgumentError, "Corrupt dataset")
    expect { described_class.new.perform(di.id) }.to raise_error(ArgumentError, "Corrupt dataset")
    expect(di.reload).to be_failed
    expect(di.error_message).to eq("Corrupt dataset")
  end

  it "does not let an expired attempt overwrite a newer processing attempt" do
    allow(processor).to receive(:call) do
      di.update!(status: "processing", attempts: 2)
      {"table" => "stale-attempt"}
    end
    described_class.new.perform(di.id)
    expect(di.reload).to be_processing
    expect(di.metadata).not_to have_key("table")
  end
end
