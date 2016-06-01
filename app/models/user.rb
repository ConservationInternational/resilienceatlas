# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
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
#  first_name             :string
#  last_name              :string
#  phone                  :string
#  organization           :string
#  organization_role      :string
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, omniauth_providers: [:facebook, :twitter, :linkedin, :google_oauth2]

  TEMP_EMAIL_PREFIX = 'change@tmp'
  TEMP_EMAIL_REGEX = /\Achange@tmp/

  has_many :identities, dependent: :destroy

  validates_uniqueness_of :email
  validates_format_of     :email, without: TEMP_EMAIL_REGEX, on: :update

  def name
    "#{first_name} #{last_name}"
  end

  def email_verified?
    email && email !~ TEMP_EMAIL_REGEX
  end

  class << self
    def for_oauth(auth, signed_in_resource = nil)
      identity = Identity.for_oauth(auth)
      user     = signed_in_resource ? signed_in_resource : identity.user

      if user.nil?
        email    = auth.info.email
        name_arr = auth.info.name.split(' ')
        user     = User.where(email: email).first if email

        update_attr(user, name_arr, auth) if user

        if user.nil?
          user = User.create(
                   email:      email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
                   password:   Devise.friendly_token[0,20],
                   first_name: name_arr[0],
                   last_name:  name_arr[1],
                   phone:      auth.info.phone
                 )
        end
      end

      if identity.user != user
        identity.user = user
        identity.save!
      end

      user
    end

    def update_attr(user, name_arr, auth)
      update_attr = {}
      update_attr['first_name'] = name_arr[0]     if user.first_name.blank?
      update_attr['last_name']  = name_arr[1]     if user.last_name.blank?
      update_attr['phone']      = auth.info.phone if user.phone.blank?
      update_attr
      user.update(update_attr)
    end
  end
end
