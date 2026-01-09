# == Schema Information
#
# Table name: feedback_fields
#
#  id                  :bigint           not null, primary key
#  feedback_id         :bigint           not null
#  parent_id           :bigint
#  feedback_field_type :string           not null
#  question            :string
#  answer              :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
require "rails_helper"

RSpec.describe FeedbackField, type: :model do
  subject { build(:feedback_field) }

  it { is_expected.to be_valid }

  it "should not be valid without feedback" do
    subject.feedback = nil
    expect(subject).to have(1).errors_on(:feedback)
  end

  it "should not be valid without answer being json" do
    subject.answer = "not json"
    expect(subject).to have(1).errors_on(:answer)
  end

  it "should not be valid when answer schema is wrong" do
    subject.answer = "wrong_json"
    expect(subject).to have(1).errors_on(:answer)

    subject.answer = {"wrong" => "json"}
    expect(subject).to have(1).errors_on(:answer)

    subject.answer = {"value" => {"wrong" => "json"}}
    expect(subject).to have(1).errors_on(:answer)

    subject.answer = {"value" => "Red", "slug" => {"wrong" => "json"}}
    expect(subject).to have(1).errors_on(:answer)
  end

  it "should be valid when answer schema is correct" do
    subject.answer = "{\"value\": 1}"
    expect(subject).not_to have(1).errors_on(:answer)

    subject.answer = {"value" => "Red"}
    expect(subject).not_to have(1).errors_on(:answer)

    subject.answer = {"value" => ["Red", "Blue"]}
    expect(subject).not_to have(1).errors_on(:answer)

    subject.answer = {"value" => "Red", "slug" => "red"}
    expect(subject).not_to have(1).errors_on(:answer)

    subject.answer = {"value" => "Red", "slug" => nil}
    expect(subject).not_to have(1).errors_on(:answer)

    subject.answer = {"value" => true, "slug" => "true"}
    expect(subject).not_to have(1).errors_on(:answer)

    subject.answer = {"value" => ["Red", "Blue"], "slug" => ["red", "blue"]}
    expect(subject).not_to have(1).errors_on(:answer)
  end
end
