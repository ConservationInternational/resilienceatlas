require "rails_helper"

RSpec.describe Feedback, type: :model do
  subject { build(:feedback) }

  it { is_expected.to be_valid }

  it "should not be valid without language" do
    subject.language = nil
    expect(subject).to have(1).errors_on(:language)
  end
end
