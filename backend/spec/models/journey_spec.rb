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
end
