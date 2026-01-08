require "rails_helper"

RSpec.describe Api::V1::SiteScopeAuthenticationsController, type: :controller do
  let(:site_scope) { create(:site_scope, subdomain: "test-site") }
  let(:protected_site) do
    create(:site_scope, subdomain: "protected-site", password_protected: true, username: "testuser", password: "password123")
  end

  describe "POST #authenticate" do
    context "with non-existent site scope" do
      it "returns 404" do
        post :authenticate, params: {site_scope: "nonexistent"}
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["errors"][0]["title"]).to eq("Site scope not found")
      end
    end

    context "with non-protected site scope" do
      it "returns success without requiring credentials" do
        post :authenticate, params: {site_scope: site_scope.subdomain}
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["authenticated"]).to be true
      end
    end

    context "with protected site scope" do
      it "returns success with valid credentials" do
        post :authenticate, params: {
          site_scope: protected_site.subdomain,
          username: "testuser",
          password: "password123"
        }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["authenticated"]).to be true
        expect(response_body["token"]).to be_present
      end

      it "returns unauthorized with invalid credentials" do
        post :authenticate, params: {
          site_scope: protected_site.subdomain,
          username: "testuser",
          password: "wrongpassword"
        }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["errors"][0]["title"]).to eq("Invalid credentials")
      end

      it "returns unauthorized with missing credentials" do
        post :authenticate, params: {site_scope: protected_site.subdomain}

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET #check_access" do
    context "with non-protected site scope" do
      it "returns authenticated without token" do
        get :check_access, params: {site_scope: site_scope.subdomain}

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["requires_authentication"]).to be false
        expect(response_body["authenticated"]).to be true
      end
    end

    context "with protected site scope" do
      it "returns not authenticated without token" do
        get :check_access, params: {site_scope: protected_site.subdomain}

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["requires_authentication"]).to be true
        expect(response_body["authenticated"]).to be false
      end

      it "returns authenticated with valid token" do
        # First authenticate to get a token
        post :authenticate, params: {
          site_scope: protected_site.subdomain,
          username: "testuser",
          password: "password123"
        }

        token = JSON.parse(response.body)["token"]

        # Then check access with the token
        request.headers["Site-Scope-Token"] = token
        get :check_access, params: {site_scope: protected_site.subdomain}

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["requires_authentication"]).to be true
        expect(response_body["authenticated"]).to be true
      end
    end
  end
end
