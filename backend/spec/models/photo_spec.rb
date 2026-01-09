# == Schema Information
#
# Table name: photos
#
#  id         :bigint           not null, primary key
#  image_data :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require "rails_helper"

RSpec.describe Photo, type: :model do
  subject { build(:photo) }

  it { is_expected.to be_valid }

  describe "image uploader" do
    it "includes ImageUploader for image field" do
      photo = create(:photo)
      expect(photo).to respond_to(:image)
      expect(photo).to respond_to(:image_url)
    end
  end

  describe "creation" do
    it "can be created without image data" do
      photo = Photo.create
      expect(photo).to be_persisted
      expect(photo.image_data).to be_nil
    end
  end
end
