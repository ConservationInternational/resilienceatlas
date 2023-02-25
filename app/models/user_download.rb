# == Schema Information
#
# Table name: user_downloads
#
#  id         :bigint           not null, primary key
#  subdomain  :string
#  user_id    :integer
#  layer_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class UserDownload < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :layer
end
