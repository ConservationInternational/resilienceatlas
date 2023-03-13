# == Schema Information
#
# Table name: journey_steps
#
#  id               :bigint           not null, primary key
#  step_type        :string           not null
#  credits          :string
#  credits_url      :string
#  source           :string
#  mask_sql         :string
#  map_url          :string
#  embedded_map_url :string
#  background_color :string
#  chapter_number   :integer
#  position         :integer          default(1), not null
#  journey_id       :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  title            :string
#  subtitle         :string
#  description      :string
#  content          :text
#
require "rails_helper"

RSpec.describe JourneyStep, type: :model do
  subject { build(:journey_step) }

  it { is_expected.to be_valid }

  it "should not be valid when credits_url is not url" do
    subject.credits_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:credits_url)
  end

  it "should not be valid when credits_url is not url" do
    subject.credits_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:credits_url)
  end

  it "should not be valid when map_url is not url" do
    subject.map_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:map_url)
  end

  it "should not be valid when embedded_map_url is not url" do
    subject.embedded_map_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:embedded_map_url)
  end

  it "should not be valid when background_image is not image" do
    subject.background_image.attach fixture_file_upload("document.pdf")
    expect(subject).to have(1).errors_on(:background_image)
  end
end
