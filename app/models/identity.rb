# == Schema Information
#
# Table name: identities
#
#  id         :bigint           not null, primary key
#  user_id    :bigint
#  provider   :string
#  uid        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Identity < ApplicationRecord
  belongs_to :user

  validates_presence_of   :uid, :provider
  validates_uniqueness_of :uid, scope: :provider

  def self.for_oauth(auth)
    find_or_create_by(uid: auth.uid, provider: auth.provider)
  end
end
