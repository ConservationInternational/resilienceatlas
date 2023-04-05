require 'rails_helper'

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

  it "should not be valid without position" do
    subject.position = nil
    expect(subject).to have(2).errors_on(:position)
  end

  it "should not be valid when position is negative" do
    subject.position = -1
    expect(subject).to have(1).errors_on(:position)
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

  context "when show_journeys is true" do
    before { subject.show_journeys = true }

    it "should not be valid without journeys_title" do
      subject.journeys_title = nil
      expect(subject.save).to be_falsey
      expect(subject.errors["translations.journeys_title"]).to include("can't be blank")
    end

    it "should not be valid without journeys_position" do
      subject.journeys_position = nil
      expect(subject).to have(2).errors_on(:journeys_position)
    end

    it "should not be valid when journeys_position is negative" do
      subject.journeys_position = -1
      expect(subject).to have(1).errors_on(:journeys_position)
    end
  end
end
