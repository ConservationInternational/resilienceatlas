# == Schema Information
#
# Table name: map_menu_entries
#
#  id         :bigint           not null, primary key
#  label      :string
#  link       :string
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ancestry   :string
#

require "rails_helper"

RSpec.describe MapMenuEntry, type: :model do
  subject { build(:map_menu_entry) }

  it { is_expected.to be_valid }

  it "should not be valid without position" do
    subject.position = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:position]).to include("can't be blank")
  end

  it "should not be valid without label" do
    subject.label = nil
    expect(subject.save).to be_falsey
    expect(subject.errors["translations.label"]).to include("can't be blank")
  end

  describe "ancestry" do
    let(:parent) { create(:map_menu_entry, label: "Parent Menu") }
    let(:child) { create(:map_menu_entry, label: "Child Menu", parent: parent) }

    it "supports parent-child relationships" do
      expect(child.parent).to eq(parent)
      expect(parent.children).to include(child)
    end

    it "destroys children when parent is destroyed with orphan strategy" do
      child # ensure child is created
      expect { parent.destroy }.to change { MapMenuEntry.count }.by(-2)
    end
  end
end
