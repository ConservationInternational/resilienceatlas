require "rails_helper"

RSpec.describe FeedbackField, type: :model do
  subject { build(:feedback_field) }

  it { is_expected.to be_valid }

  it "should not be valid without feedback" do
    subject.feedback = nil
    expect(subject).to have(1).errors_on(:feedback)
  end

  it "should not be valid without answers being json" do
    subject.answers = "not json"
    expect(subject).to have(1).errors_on(:answers)
  end

  it "should not be valid when answers schema is wrong" do
    subject.answers = "wrong_json"
    expect(subject).to have(1).errors_on(:answers)

    subject.answers = {"wrong" => "json"}
    expect(subject).to have(1).errors_on(:answers)

    subject.answers = [{"wrong" => "json"}]
    expect(subject).to have(1).errors_on(:answers)

    subject.answers = [{"value" => {"wrong" => "json"}}]
    expect(subject).to have(1).errors_on(:answers)

    subject.answers = [{"value" => "Red", "slug" => {"wrong" => "json"}}]
    expect(subject).to have(1).errors_on(:answers)
  end

  it "should be valid when answers schema is correct" do
    subject.answers = "[{\"value\": 1}]"
    expect(subject).not_to have(1).errors_on(:answers)

    subject.answers = [{"value" => "Red"}]
    expect(subject).not_to have(1).errors_on(:answers)

    subject.answers = [{"value" => ["Red", "Blue"]}]
    expect(subject).not_to have(1).errors_on(:answers)

    subject.answers = [{"value" => "Red", "slug" => "red"}]
    expect(subject).not_to have(1).errors_on(:answers)

    subject.answers = [{"value" => "Red", "slug" => nil}]
    expect(subject).not_to have(1).errors_on(:answers)

    subject.answers = [{"value" => true, "slug" => "true"}]
    expect(subject).not_to have(1).errors_on(:answers)

    subject.answers = [{"value" => ["Red", "Blue"], "slug" => ["red", "blue"]}]
    expect(subject).not_to have(1).errors_on(:answers)
  end
end
