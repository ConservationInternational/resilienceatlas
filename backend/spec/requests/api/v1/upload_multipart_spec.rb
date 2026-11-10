require "rails_helper"
require "aws-sdk-s3"

RSpec.describe "Upload multipart coordination", type: :request do
  let(:admin) { create(:admin_user, role: :superadmin) }
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:di) do
    SpatialUploadLifecycle.create!(admin, {"import_type" => "vector", "mode" => "dataset",
      "file_name" => "points.geojson", "file_size_bytes" => 123})
  end

  before do
    sign_in admin
    allow(Aws::S3::Client).to receive(:new).and_return(client)
    client.stub_responses(:create_multipart_upload, upload_id: "upload-id")
    client.stub_responses(:head_object, content_length: 123)
  end

  def start_upload
    post "/api/uploads/multipart", params: {filename: di.file_name, metadata: {session_id: di.id, size: 123}}, as: :json
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  it "persists session ownership and resumes the same multipart upload" do
    first = start_upload
    second = start_upload
    expect(second).to eq(first)
    expect(client.api_requests.count { |request| request[:operation_name] == :create_multipart_upload }).to eq(1)
  end

  it "signs valid part numbers and rejects invalid ones" do
    upload = start_upload
    get "/api/uploads/multipart/upload-id", params: {key: upload["key"], partNumbers: [0]}, as: :json
    expect(response).to have_http_status(:bad_request)
    get "/api/uploads/multipart/upload-id", params: {key: upload["key"], partNumbers: [1]}, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["presignedUrls"]["1"]).to include("uploadId=upload-id")
  end

  it "lists real parts for resume and verifies completed object size" do
    upload = start_upload
    client.stub_responses(:list_parts, parts: [{part_number: 1, etag: "etag", size: 123}])
    get "/api/uploads/multipart/upload-id", params: {key: upload["key"], list: "1"}, as: :json
    expect(response.parsed_body["parts"].first["Size"]).to eq(123)
    2.times do
      post "/api/uploads/multipart/upload-id/complete", params: {key: upload["key"], parts: [{PartNumber: 1, ETag: "etag"}]}, as: :json
      expect(response).to have_http_status(:ok)
    end
    expect(di.reload.metadata["transferred"]).to be(true)
    expect(client.api_requests.count { |request| request[:operation_name] == :complete_multipart_upload }).to eq(1)
  end

  it "does not sign another user's upload or an arbitrary S3 key" do
    upload = start_upload
    sign_in create(:admin_user, role: :superadmin)
    get "/api/uploads/multipart/upload-id", params: {key: upload["key"], partNumbers: [1]}, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "keeps the existing CSV URL compatible" do
    post "/api/v1/uploads/multipart", params: {filename: "data.csv", metadata: {size: 123, prefix: "staging"}}, as: :json
    expect(response).to have_http_status(:ok)
    expect(DataImport.last.options["workflow"]).to eq("legacy_csv")
  end
end
