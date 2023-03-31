require "rails_helper"

RSpec.describe SiteScope, type: :model do
  subject { build(:site_scope) }

  it { is_expected.to be_valid }

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
end
