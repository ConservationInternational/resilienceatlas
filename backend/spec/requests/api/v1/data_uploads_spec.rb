require "rails_helper"
require "sidekiq/testing"

RSpec.describe "Spatial upload workspace", type: :request do
  let(:admin) { create(:admin_user, role: :superadmin) }
  let(:attributes) do
    {import_type: "vector", file_name: "points.geojson", file_size_bytes: 123,
     mode: "create", name: "Uploaded points", slug: "uploaded-points"}
  end
  let(:storage) { instance_double(UploadStorage) }

  before do
    sign_in admin
    allow(UploadStorage).to receive(:new).and_return(storage)
    allow(storage).to receive(:head).and_return(double(content_length: 123))
    allow(storage).to receive(:abort)
  end

  def body
    response.parsed_body
  end

  def create_upload(overrides = {})
    SpatialUploadLifecycle.create!(admin, attributes.merge(overrides).stringify_keys)
  end

  it "renders a real upload link even with no history and empty filters" do
    [admin_data_imports_path, admin_data_imports_path(q: {file_name_cont: "no-such-file"})].each do |url|
      get url
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(upload_admin_data_imports_path)
      expect(response.body).not_to include("scrollIntoView")
    end
    get upload_admin_data_imports_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="spatial-upload"', "/api/uploads/sessions")
  end

  it "creates an upload without a fake polymorphic target" do
    post api_data_uploads_path, params: attributes, as: :json
    expect(response).to have_http_status(:created)
    di = DataImport.find(body.fetch("id"))
    expect(di).to be_uploading
    expect(di.importable).to be_nil
  end

  it "rejects unsupported, empty and oversized files" do
    [{file_name: "bad.exe"}, {file_size_bytes: 0}, {file_size_bytes: SpatialUploadLifecycle.max_bytes + 1}].each do |invalid|
      post api_data_uploads_path, params: attributes.merge(invalid), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body["error"]).to be_present
    end
  end

  it "uses Sidekiq and queues finalization exactly once" do
    di = create_upload
    di.update!(s3_key: "staging/uploads/#{di.id}/points.geojson", metadata: {"transferred" => true})
    Sidekiq::Testing.fake! do
      expect {
        2.times { post process_file_api_data_upload_path(di), as: :json }
      }.to change(SpatialUploadJob.jobs, :size).by(1)
    end
    expect(response).to have_http_status(:ok)
    expect(di.reload).to be_pending
  end

  it "does not accept someone else's upload" do
    di = create_upload
    sign_in create(:admin_user, role: :superadmin)
    get api_data_upload_path(di), as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "records a queue failure instead of leaving unexplained pending work" do
    di = create_upload
    di.update!(s3_key: "staging/file", metadata: {"transferred" => true})
    allow(SpatialUploadJob).to receive(:perform_async).and_raise(IOError, "Redis unavailable")
    post process_file_api_data_upload_path(di), as: :json
    expect(response).to have_http_status(:service_unavailable)
    expect(di.reload).to be_failed
    expect(di.error_message).to include("Redis unavailable")
  end

  it "requires a verified preview before finalization" do
    di = create_upload
    di.update!(status: "ready")
    post finalize_api_data_upload_path(di), as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(di.reload).to be_ready
  end

  it "cancels without changing a replacement layer" do
    layer = create(:layer)
    original = layer.layer_config
    di = create_upload("mode" => "replace", "layer_id" => layer.id)
    post cancel_api_data_upload_path(di), as: :json
    expect(response).to have_http_status(:ok)
    expect(di.reload).to be_cancelled
    expect(layer.reload.layer_config).to eq(original)
  end

  it "keeps layer entry points on the same workspace" do
    layer = create(:layer)
    get import_vector_admin_layer_path(layer)
    expect(response).to redirect_to(upload_admin_data_imports_path(layer_id: layer.id, import_type: "vector"))
    get upload_cog_admin_layer_path(layer)
    expect(response).to redirect_to(upload_admin_data_imports_path(layer_id: layer.id, import_type: "cog"))
  end

  it "configures and finalizes a multiband raster as an unpublished COG layer" do
    di = create_upload("import_type" => "cog", "file_name" => "raster.tif")
    di.update!(status: "ready", metadata: {"transferred" => true,
                                           "source" => "s3://resilienceatlas/cogs/imports/immutable.tif",
                                           "bounds" => [1, 2, 3, 4], "bands" => [{}, {}, {}]})
    patch configure_api_data_upload_path(di), params: {bidx: "1,2,3", raster_kind: "rgb",
                                                       colormap: "", popup_fields: []}, as: :json
    expect(response).to have_http_status(:ok)
    # Changed overview interpretation requires reprocessing, not just changing display.
    expect(di.reload).to be_needs_input
    di.update!(status: "ready")
    allow_any_instance_of(UploadTileService).to receive(:verify!).and_return(true)
    post verify_api_data_upload_path(di), as: :json
    expect(response).to have_http_status(:ok)
    post finalize_api_data_upload_path(di), as: :json
    expect(response).to have_http_status(:ok)
    layer = di.reload.importable
    expect(layer).not_to be_published
    expect(layer.layer_provider).to eq("cog")
    expect(JSON.parse(layer.layer_config).dig("body", "bidx")).to eq("1,2,3")
    expect(JSON.parse(layer.interaction_config).dig("config", "url")).to include("bidx[]=1&bidx[]=2&bidx[]=3")
  end
end
