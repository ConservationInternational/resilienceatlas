require "rails_helper"

RSpec.describe Blobs::GetLink do
  subject { described_class.new blob, **options }

  let(:options) { {resize: "200x200"} }

  describe "#call" do
    context "when blob is image" do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload! io: fixture_file_upload("picture.jpg"), filename: "test", service_name: "test"
      end

      it "returns link to blob" do
        expect(subject.call).to be_kind_of(String)
      end
    end

    context "when blob is nil" do
      let(:blob) { nil }

      it "is nil" do
        expect(subject.call).to be_nil
      end
    end
  end
end
