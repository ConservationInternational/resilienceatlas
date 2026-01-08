# == Schema Information
#
# Table name: site_scopes
#
#  id               :bigint           not null, primary key
#  color            :string
#  subdomain        :string
#  has_analysis     :boolean          default(FALSE)
#  latitude         :float
#  longitude        :float
#  header_theme     :string
#  zoom_level       :integer          default(3)
#  linkback_url     :text
#  header_color     :string
#  logo_url         :text
#  predictive_model :boolean          default(FALSE), not null
#  analysis_options :boolean          default(FALSE), not null
#  has_gef_logo     :boolean
#  name             :string
#  linkback_text    :text
#
require "rails_helper"

RSpec.describe SiteScope, type: :model do
  subject { build(:site_scope) }

  it { is_expected.to be_valid }

  it "should not be valid without name" do
    subject.name = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.name"]).to include("can't be blank")
  end

  describe "#clone!" do
    let!(:site_scope) { create :site_scope }
    let(:cloned_site_scope) { SiteScope.where.not(id: site_scope.id).last }

    before do
      I18n.with_locale(:es) { site_scope.update! name: "Name ES", linkback_text: "Linkback Text ES" } # add extra translation
      site_scope.clone!
    end

    it "clones basic attributes" do
      expect(cloned_site_scope.attributes.except("id", "name")).to eq(site_scope.attributes.except("id", "name"))
    end

    it "clones translations" do
      expect(cloned_site_scope.translations.map { |t| t.attributes.except("id", "name", "site_scope_id", "created_at", "updated_at") })
        .to match_array(site_scope.translations.map { |t| t.attributes.except("id", "name", "site_scope_id", "created_at", "updated_at") })
    end

    it "updates name of cloned site scope" do
      expect(cloned_site_scope.name).to include("#{site_scope.name} _copy_ ")
    end
  end

  describe "password protection" do
    let(:site_scope) { create(:site_scope) }

    context "when password_protected is false" do
      it "does not require authentication" do
        expect(site_scope.requires_authentication?).to be false
      end

      it "does not validate username and password" do
        site_scope.password_protected = false
        site_scope.username = nil
        site_scope.password = nil
        expect(site_scope).to be_valid
      end
    end

    context "when password_protected is true" do
      let(:protected_site_scope) { create(:site_scope) }
      before { protected_site_scope.password_protected = true }

      it "validates presence of username" do
        protected_site_scope.username = nil
        expect(protected_site_scope).not_to be_valid
        expect(protected_site_scope.errors[:username]).to include("can't be blank")
      end

      it "validates presence of password when password is provided" do
        protected_site_scope.username = "testuser"
        protected_site_scope.password = ""
        expect(protected_site_scope).to be_valid # empty password is allowed for updates

        protected_site_scope.password = "short"
        expect(protected_site_scope).not_to be_valid
        expect(protected_site_scope.errors[:password]).to include("is too short (minimum is 6 characters)")
      end

      it "encrypts password on save" do
        protected_site_scope.username = "testuser"
        protected_site_scope.password = "password123"
        protected_site_scope.save!

        expect(protected_site_scope.encrypted_password).to be_present
        expect(protected_site_scope.encrypted_password).not_to eq("password123")
      end

      it "requires authentication when properly configured" do
        protected_site_scope.username = "testuser"
        protected_site_scope.password = "password123"
        protected_site_scope.save!

        expect(protected_site_scope.requires_authentication?).to be true
      end
    end

    describe "#authenticate_with_password" do
      let(:protected_site) do
        create(:site_scope, password_protected: true, username: "testuser", password: "password123")
      end

      it "returns true for valid credentials" do
        expect(protected_site.authenticate_with_password("testuser", "password123")).to be true
      end

      it "returns false for invalid username" do
        expect(protected_site.authenticate_with_password("wronguser", "password123")).to be false
      end

      it "returns false for invalid password" do
        expect(protected_site.authenticate_with_password("testuser", "wrongpassword")).to be false
      end

      it "returns false for non-protected site" do
        expect(site_scope.authenticate_with_password("testuser", "password123")).to be false
      end
    end

    describe "#clone!" do
      let(:cloneable_site_scope) { create(:site_scope) }

      it "resets password protection for cloned site" do
        cloneable_site_scope.update!(password_protected: true, username: "testuser", password: "password123")

        cloned = cloneable_site_scope.clone!

        expect(cloned.password_protected).to be false
        expect(cloned.encrypted_password).to be_nil
        expect(cloned.encrypted_viewable_password).to be_nil
      end
    end

    describe "#viewable_password" do
      it "returns nil when no password is set" do
        expect(site_scope.viewable_password).to be_nil
      end

      it "returns the decrypted password when set" do
        site_scope.password_protected = true
        site_scope.username = "testuser"
        site_scope.password = "password123"
        site_scope.save!

        expect(site_scope.viewable_password).to eq("password123")
      end

      it "returns nil for corrupted encrypted data" do
        site_scope.update_column(:encrypted_viewable_password, "corrupted_data")
        expect(site_scope.viewable_password).to be_nil
      end
    end
  end
end
