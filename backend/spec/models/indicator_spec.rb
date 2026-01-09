# == Schema Information
#
# Table name: indicators
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  version     :string
#  created_at  :datetime         default(Tue, 28 Mar 2023 22:07:16.747487000 CEST +02:00), not null
#  updated_at  :datetime         default(Tue, 28 Mar 2023 22:07:16.747956000 CEST +02:00), not null
#  category_id :integer
#  position    :integer
#  column_name :string
#  operation   :string
#  name        :string
#

require "rails_helper"

RSpec.describe Indicator, type: :model do
  subject { build(:indicator) }

  it { is_expected.to be_valid }

  it "should not be valid without slug" do
    subject.slug = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:slug]).to include("can't be blank")
  end

  it "should not be valid without name" do
    subject.name = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.name"]).to include("can't be blank")
  end

  describe "acts_as_list" do
    let(:category) { create(:category) }
    let!(:indicator1) { create(:indicator, category: category, position: 1) }
    let!(:indicator2) { create(:indicator, category: category, position: 2) }

    it "maintains position within category scope" do
      expect(indicator1.position).to eq(1)
      expect(indicator2.position).to eq(2)
    end
  end

  describe ".fetch_all" do
    let!(:indicator) { create(:indicator) }

    it "returns all indicators with translations" do
      indicators = Indicator.fetch_all
      expect(indicators).to include(indicator)
    end
  end
end
