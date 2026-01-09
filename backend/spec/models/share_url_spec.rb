# == Schema Information
#
# Table name: share_urls
#
#  id         :bigint           not null, primary key
#  uid        :string
#  body       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require "rails_helper"

RSpec.describe ShareUrl, type: :model do
  subject { build(:share_url, uid: nil) }

  it { is_expected.to be_valid }

  it "should not be valid without body" do
    subject.body = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:body]).to include("can't be blank")
  end

  describe "uid generation" do
    it "generates a uid before creation" do
      share_url = ShareUrl.create(body: "test body")
      expect(share_url.uid).to be_present
      expect(share_url.uid.length).to eq(20)
    end

    it "generates unique uids" do
      share_url1 = ShareUrl.create(body: "test body 1")
      share_url2 = ShareUrl.create(body: "test body 2")
      expect(share_url1.uid).not_to eq(share_url2.uid)
    end

    it "regenerates uid if collision occurs" do
      # Create a share_url with a specific uid
      existing = ShareUrl.create(body: "existing")

      # Mock SecureRandom to return the existing uid first, then a new one
      allow(SecureRandom).to receive(:hex).with(10).and_return(existing.uid, "newuniqueid123")

      new_share_url = ShareUrl.create(body: "new body")
      expect(new_share_url.uid).to eq("newuniqueid123")
      expect(new_share_url.uid).not_to eq(existing.uid)
    end
  end
end
