# == Schema Information
#
# Table name: admin_users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :inet
#  last_sign_in_ip        :inet
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  role                   :integer          default("admin")
#  provider               :string           default("email"), not null
#  uid                    :string           default(""), not null
#  allow_password_change  :boolean          default(FALSE)
#  name                   :string
#  nickname               :string
#  image                  :string
#  tokens                 :json
#  confirmation_token     :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#

class AdminUser < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable

  ROLES = %i[
    admin
    manager
    staff
  ].freeze

  enum :role, ROLES

  # Ransack configuration - explicitly allowlist searchable attributes for security
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id email name nickname role created_at updated_at sign_in_count
      current_sign_in_at last_sign_in_at current_sign_in_ip last_sign_in_ip
      remember_created_at provider uid confirmation_token confirmed_at
      confirmation_sent_at unconfirmed_email
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
