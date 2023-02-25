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

class ShareUrl < ApplicationRecord
  before_create :create_uid
  validates_presence_of :body

  private

  def create_uid
    while uid.blank? || !ShareUrl.find_by(uid: uid).blank?
      self.uid = SecureRandom.hex(10)
    end
  end
end
