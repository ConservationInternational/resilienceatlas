# == Schema Information
#
# Table name: homepage_sections
#
#  id                :bigint           not null, primary key
#  homepage_id       :bigint           not null
#  button_url        :string
#  image_position    :string
#  image_credits_url :string
#  background_color  :string
#  position          :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string
#  subtitle          :string
#  button_text       :string
#  image_credits     :string
#
require 'rails_helper'

RSpec.describe HomepageSection, type: :model do
  subject { build(:homepage_section) }

  it { is_expected.to be_valid }

  it "should not be valid when button_url is not url" do
    subject.button_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:button_url)
  end

  it "should not be valid when image_credits_url is not url" do
    subject.image_credits_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:image_credits_url)
  end

  it "should not be valid without image" do
    subject.image = nil
    expect(subject).to have(1).errors_on(:image)
  end

  it "should not be valid without image_position" do
    subject.image_position = nil
    expect(subject).to have(1).errors_on(:image_position)
  end

  it "should not be valid when image is not image" do
    subject.image.attach fixture_file_upload("document.pdf")
    expect(subject).to have(1).errors_on(:image)
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
end
