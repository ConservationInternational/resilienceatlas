require "rails_helper"

RSpec.describe StaticPage::Base, type: :model do
  subject { build(:static_page) }

  it { is_expected.to be_valid }

  it "should not be valid without slug" do
    subject.slug = nil
    expect(subject).to have(1).errors_on(:slug)
  end

  it "should not be valid when slug is not uniq" do
    subject.save!
    expect(build(:static_page, slug: subject.slug)).to have(1).errors_on(:slug)
  end

  it "should not be valid when image_credits_url is not url" do
    subject.image_credits_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:image_credits_url)
  end

  it "should not be valid without image" do
    subject.image = nil
    expect(subject).to have(1).errors_on(:image)
  end

  it "should not be valid when image is not image" do
    subject.image.attach fixture_file_upload("document.pdf")
    expect(subject).to have(1).errors_on(:image)
  end

  it "should not be valid without title" do
    subject.title = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.title"]).to include("can't be blank")
  end
end
