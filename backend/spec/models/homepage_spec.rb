# == Schema Information
#
# Table name: homepages
#
#  id                  :bigint           not null, primary key
#  homepage_journey_id :bigint
#  site_scope_id       :bigint           not null
#  credits_url         :string
#  show_journeys       :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  title               :string
#  subtitle            :string
#  credits             :string
#
require "rails_helper"

RSpec.describe Homepage, type: :model do
  subject { build(:homepage) }

  it { is_expected.to be_valid }

  it "should not be valid when credits_url is not url" do
    subject.credits_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:credits_url)
  end

  it "should not be valid without background_image" do
    subject.background_image = nil
    expect(subject).to have(1).errors_on(:background_image)
  end

  it "should not be valid when background_image is not image" do
    subject.background_image.attach fixture_file_upload("document.pdf")
    expect(subject).to have(1).errors_on(:background_image)
  end

  it "should not be valid without title" do
    subject.title = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.title"]).to include("can't be blank")
  end

  it "should not be valid without subtitle" do
    subject.subtitle = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.subtitle"]).to include("can't be blank")
  end

  it "should not be valid when multiple homepages uses same site scope" do
    expect(build(:homepage, site_scope: create(:homepage).site_scope)).to have(1).errors_on(:site_scope_id)
  end

  context "when show_journeys is true" do
    subject { build(:homepage, show_journeys: true) }

    it "should not be valid without homepage_journey" do
      subject.homepage_journey = nil
      expect(subject).to have(1).errors_on(:homepage_journey)
    end
  end
end
