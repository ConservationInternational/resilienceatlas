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
  devise :database_authenticatable, :recoverable, :rememberable,
    :trackable, :validatable, :lockable, :timeoutable

  # Role hierarchy (stored as integer — values are fixed; do NOT reassign):
  #   0 admin       — full CRUD within assigned site scopes
  #   2 staff       — create-only within assigned site scopes; layers always published=false
  #   3 superadmin  — unrestricted: all site scopes, all actions
  #   4 contributor — create-only within assigned site scopes; layers always published=false
  # (integer 1 was "manager", removed — existing DB rows migrated to admin=0)
  ROLES = %i[admin staff superadmin contributor].freeze

  enum :role, { admin: 0, staff: 2, superadmin: 3, contributor: 4 }

  has_many :admin_user_site_scopes, dependent: :destroy
  has_many :allowed_site_scopes, through: :admin_user_site_scopes, source: :site_scope

  # Returns true when this user can operate across all site scopes without restriction.
  # NOTE: the enum already generates superadmin? — this is kept for explicitness.

  # Returns true when this user can only create (not update/delete) layers via the agent.
  # Intentionally overrides the enum predicate to cover both :contributor and :staff roles,
  # which share identical restricted behaviour (create-only, always published=false).
  def contributor?
    role == "contributor" || role == "staff"
  end

  # Returns the site scope IDs this user is allowed to operate on.
  # Superadmins get the sentinel value "*" meaning "all".
  def allowed_site_scope_ids_for_agent
    return "*" if superadmin?

    allowed_site_scopes.pluck(:id).map(&:to_s)
  end

  # Ransack configuration - explicitly allowlist searchable attributes for security
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id email name nickname role created_at updated_at sign_in_count
      current_sign_in_at last_sign_in_at current_sign_in_ip last_sign_in_ip
      remember_created_at provider uid confirmed_at
      confirmation_sent_at unconfirmed_email
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
