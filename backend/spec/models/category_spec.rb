# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  name        :string
#  description :text
#

require "rails_helper"

RSpec.describe Category, type: :model do
  subject { build(:category) }

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

  describe "associations" do
    it { is_expected.to have_many(:indicators).dependent(:restrict_with_error) }
  end

  describe ".fetch_all" do
    let!(:category) { create(:category) }

    it "returns all categories with translations" do
      categories = Category.fetch_all
      expect(categories).to include(category)
    end
  end
end
