# == Schema Information
#
# Table name: static_page_section_paragraphs
#
#  id                :bigint           not null, primary key
#  section_id        :bigint           not null
#  image_position    :string           not null
#  image_credits_url :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  text              :text
#  image_credits     :string
#
require "rails_helper"

RSpec.describe StaticPage::SectionParagraph, type: :model do
  subject { build(:static_page_section_paragraph) }

  it { is_expected.to be_valid }

  it "should not be valid when image_credits_url is not url" do
    subject.image_credits_url = "WRONG_URL"
    expect(subject).to have(1).errors_on(:image_credits_url)
  end

  it "should not be valid when image is not image" do
    subject.image.attach fixture_file_upload("document.pdf")
    expect(subject).to have(1).errors_on(:image)
  end
end
