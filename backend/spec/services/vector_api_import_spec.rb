require "rails_helper"

RSpec.describe VectorApiImport do
  let(:storage) { instance_double(UploadStorage, bucket: "resilienceatlas") }
  let(:conn) { ActiveRecord::Base.connection }

  before do
    allow(UploadStorage).to receive(:new).and_return(storage)
    allow(storage).to receive(:head).and_return(double(content_length: 10))
  end

  it "rejects a foreign bucket before reading it" do
    expect(storage).not_to receive(:head)
    expect { described_class.new("s3://foreign-bucket/data.geojson", "data").call }.to raise_error(ArgumentError, /configured upload bucket/)
  end

  it "does not overwrite an existing vector table" do
    allow(conn).to receive(:select_value).and_return("ra_vector.live_table")
    expect(storage).not_to receive(:download)
    expect { described_class.new("s3://resilienceatlas/data.geojson", "live_table").call }.to raise_error(ArgumentError, /already exists/)
  end
end
