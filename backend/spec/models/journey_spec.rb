# == Schema Information
#
# Table name: journeys
#
#  id          :bigint           not null, primary key
#  credits     :string
#  credits_url :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  published   :boolean          default(FALSE), not null
#  title       :string
#  subtitle    :string
#  theme       :text
#
require "rails_helper"

RSpec.describe Journey, type: :model do
  subject { build(:journey) }

  it { is_expected.to be_valid }

  it "should not be valid when credits_url is not url" do
    subject.credits_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:credits_url)
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

  it "should not be valid without journey steps" do
    subject.save!
    subject.journey_steps = []
    expect(subject.save).to be_falsey
    expect(subject.errors[:journey_steps]).to include("can't be blank")
  end
end
