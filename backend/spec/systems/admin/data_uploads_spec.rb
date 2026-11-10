require "system_helper"
require "aws-sdk-s3"
require "sidekiq/testing"

RSpec.describe "Admin data upload workspace", type: :system do
  let(:admin) { create(:admin_user, role: :superadmin) }

  before { login_as admin }

  it "opens the workspace from empty and filtered upload history and initializes JavaScript" do
    visit admin_data_imports_path
    click_link "Upload New Data"
    expect(page).to have_current_path(upload_admin_data_imports_path)
    expect(page).to have_css('#spatial-upload[data-initialized="true"]')
    select "Raster (GeoTIFF / COG)", from: "Data type"
    expect(find("#upload-file")[:accept]).to eq(".tif,.tiff")
    visit admin_data_imports_path(q: {file_name_cont: "no-result"})
    click_link "Upload New Data"
    expect(page).to have_css("#upload-start")
  end

  it "transfers multiple parts through the browser and queues processing once" do
    file = Tempfile.new(["multipart-points", ".geojson"])
    file.write(" " * (16.megabytes + 32))
    file.flush
    client = Aws::S3::Client.new(stub_responses: true)
    client.stub_responses(:create_multipart_upload, upload_id: "browser-upload")
    client.stub_responses(:head_object, content_length: File.size(file.path))
    allow(Aws::S3::Client).to receive(:new).and_return(client)
    allow(UploadStorage).to receive(:new).and_return(double(head: double(content_length: File.size(file.path))))
    visit upload_admin_data_imports_path
    expect(page).to have_css('#spatial-upload[data-initialized="true"]')
    page.execute_script(<<~JS)
      window.uploadedParts = 0;
      window.XMLHttpRequest = class {
        constructor() { this.upload = {}; }
        open() {}
        send(blob) {
          window.uploadedParts++;
          this.status = 200;
          this.upload.onprogress({loaded: blob.size});
          setTimeout(() => this.onload(), 0);
        }
        getResponseHeader() { return '"browser-etag"'; }
        abort() { this.onabort?.(); }
      };
    JS
    fill_in "Layer name", with: "Browser layer"
    fill_in "upload-slug", with: "browser-layer"
    attach_file "upload-file", file.path
    Sidekiq::Testing.fake! do
      click_button "Upload / resume"
      expect(page).to have_text("Queued (upload #")
      expect(SpatialUploadJob.jobs.size).to eq(1)
    end
    expect(page.evaluate_script("window.uploadedParts")).to eq(2)
    expect(DataImport.last).to be_pending
    expect(DataImport.last.metadata["transferred"]).to be(true)
  ensure
    file&.close!
  end
end
