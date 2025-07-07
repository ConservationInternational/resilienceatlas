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

  # Ransack configuration - explicitly allowlist searchable attributes for security
  def self.ransackable_attributes(auth_object = nil)
    %w[id subdomain user_id layer_id created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[user layer]
  end
end
