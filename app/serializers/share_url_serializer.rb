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

class ShareUrlSerializer < ActiveModel::Serializer
  cache key: "share_url"
  attributes :uid, :body
  def type
    'share_url'
  end
end
