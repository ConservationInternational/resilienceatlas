# == Schema Information
#
# Table name: admin_user_site_scopes
#
#  id             :bigint   not null, primary key
#  admin_user_id  :bigint   not null
#  site_scope_id  :bigint   not null
#  created_at     :datetime not null
#  updated_at     :datetime not null
#

class AdminUserSiteScope < ApplicationRecord
  belongs_to :admin_user
  belongs_to :site_scope

  validates :site_scope_id, uniqueness: {scope: :admin_user_id}
end
