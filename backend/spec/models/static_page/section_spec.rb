require "rails_helper"

RSpec.describe StaticPage::Section, type: :model do
  subject { build(:static_page_section) }

  it { is_expected.to be_valid }

  it "should not be valid without section_type" do
    subject.section_type = nil
    expect(subject).to have(1).errors_on(:section_type)
  end

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
end
