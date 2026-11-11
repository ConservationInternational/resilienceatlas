require "rails_helper"

RSpec.describe "Data access policies" do
  it "does not fail open for an incompletely configured protected scope" do
    expect(SiteScope.new(password_protected: true).requires_authentication?).to be true
  end

  it "allows only date substitutions within a configured source" do
    template = "s3://private/{{year}}/{{month}}/{{day}}.tif"
    expect(LayerDataSources.matches?(template, "s3://private/2026/11/01.tif")).to be true
    expect(LayerDataSources.matches?(template, "s3://private/2026/99/01.tif")).to be false
    expect(LayerDataSources.matches?(template, "s3://private/../../secret.tif")).to be false
  end

  it "extracts COG sources from URLs with tile placeholders" do
    layer = Layer.new(layer_config: {body: {url: "https://titiler.resilienceatlas.org/tiles/{z}/{x}/{y}?url=s3%3A%2F%2Fprivate%2Fsource.tif"}}.to_json)
    expect(LayerDataSources.cog_urls(layer)).to eq(["s3://private/source.tif"])
  end

  it "signs only an exact resource with a short expiration" do
    stub_const("ENV", ENV.to_h.merge("DATA_GATEWAY_SECRET" => "s" * 32))
    expires, digest = DataGatewaySignature.for("s3://private/source.tif").split(":")
    expect(expires.to_i).to be_within(2).of(1.minute.from_now.to_i)
    expect(digest).to eq(OpenSSL::HMAC.hexdigest("SHA256", "s" * 32, "#{expires}\ns3://private/source.tif"))
  end

  it "never treats a user's token as a preview token" do
    token = JWT.encode({site_scope_id: 1, exp: 1.hour.from_now.to_i}, Rails.application.secret_key_base, "HS256")
    expect(AdminPreviewAccess.resolve(token, Layer)).to be_nil
  end

  it "rechecks scope assignments on upload previews and permits read-only completed contributor uploads" do
    scope = create(:site_scope)
    actor = create(:admin_user, role: :contributor, allowed_site_scopes: [scope])
    upload = DataImport.create!(admin_user: actor, import_type: "vector", status: "ready",
      options: {"mode" => "create", "site_scope_id" => scope.id})
    token = AdminPreviewAccess.issue(upload, actor)
    expect(AdminPreviewAccess.resolve(token, DataImport)).to eq(upload)
    layer = create(:layer, published: false, layer_groups: [create(:layer_group, site_scope: scope)])
    upload.update!(importable: layer, status: "complete")
    expect { Ability.new(actor).authorize_upload!(upload, read_only: true) }.not_to raise_error
    expect { Ability.new(actor).authorize_upload!(upload) }.to raise_error(CanCan::AccessDenied)
    actor.allowed_site_scopes.clear
    expect(AdminPreviewAccess.resolve(token, DataImport)).to be_nil
  end
end
