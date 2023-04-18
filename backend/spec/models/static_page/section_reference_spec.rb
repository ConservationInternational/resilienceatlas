require "rails_helper"

RSpec.describe StaticPage::SectionReference, type: :model do
  subject { build(:static_page_section_reference) }

  it { is_expected.to be_valid }

  it "should not be valid without position" do
    subject.position = nil
    expect(subject).to have(2).errors_on(:position)
  end

  it "should not be valid when position is negative" do
    subject.position = -1
    expect(subject).to have(1).errors_on(:position)
  end
end
