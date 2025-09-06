# == Schema Information
#
# Table name: static_page_section_items
#
#  id          :bigint           not null, primary key
#  section_id  :bigint           not null
#  position    :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  title       :string
#  description :text
#
require "rails_helper"

RSpec.describe StaticPage::SectionItem, type: :model do
  subject { build(:static_page_section_item) }

  it { is_expected.to be_valid }

  it "should not be valid without title" do
    subject.title = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.title"]).to include("can't be blank")
  end

  it "should not be valid without position" do
    subject.position = nil
    expect(subject).to have(2).errors_on(:position)
  end

  it "should not be valid when position is negative" do
    subject.position = -1
    expect(subject).to have(1).errors_on(:position)
  end

  it "should not be valid when image is not image" do
    subject.image.attach fixture_file_upload("document.pdf")
    expect(subject).to have(1).errors_on(:image)
  end
end
