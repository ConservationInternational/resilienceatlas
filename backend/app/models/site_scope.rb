# == Schema Information
#
# Table name: site_scopes
#
#  id               :bigint           not null, primary key
#  name             :string
#  color            :string
#  subdomain        :string
#  has_analysis     :boolean          default(FALSE)
#  latitude         :float
#  longitude        :float
#  header_theme     :string
#  zoom_level       :integer          default(3)
#  linkback_text    :text
#  linkback_url     :text
#  header_color     :string
#  logo_url         :text
#  predictive_model :boolean          default(FALSE), not null
#  analysis_options :boolean          default(FALSE), not null
#  has_gef_logo     :boolean
#  password_protected :boolean        default(FALSE), not null
#  username         :string
#  encrypted_password :string
#

class SiteScope < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :name, :linkback_text, touch: true, fallbacks_for_empty_translations: true
  end

  require "bcrypt"

  has_one :homepage, dependent: :destroy
  has_many :layer_groups
  has_many :site_pages

  # Translation setup - only initialize if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  if !defined?(Rails::Generators) && !(Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if ActiveRecord::Base.connection&.table_exists?(:site_scopes)
        translates :name, :linkback_text, touch: true, fallbacks_for_empty_translations: true
        active_admin_translates :name, :linkback_text

        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :name, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      # Database not available yet - skip translation setup for now
      Rails.logger&.info "Skipping SiteScope translations setup - database not ready"
    end
  end

  # Password protection validations
  validates :username, presence: true, if: :password_protected?
  validates :password, presence: true, if: -> { password_protected? && password.present? }
  validates :password, length: {minimum: 6}, if: -> { password_protected? && password.present? }

  # Virtual attribute for password
  attr_accessor :password

  before_save :encrypt_password, if: -> { password_protected? && password.present? }

  def location
    [:latitude, :longitude]
  end

  def clone!
    new_site_scope = SiteScope.new
    new_site_scope.assign_attributes attributes.except("id", "encrypted_password")
    translations.each { |t| new_site_scope.translations.build t.attributes.except("id") }
    new_site_scope.name = "#{name} _copy_ #{DateTime.now}"
    new_site_scope.password_protected = false # Reset password protection for cloned site
    new_site_scope.save!
    new_site_scope
  end

  # Check if provided credentials are valid for this site scope
  def authenticate_with_password(provided_username, provided_password)
    return false unless password_protected?
    return false unless username.present? && encrypted_password.present?
    return false unless username == provided_username

    BCrypt::Password.new(encrypted_password) == provided_password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  # Check if a site scope requires authentication
  def requires_authentication?
    password_protected? && username.present? && encrypted_password.present?
  end

  private

  def encrypt_password
    if password.present?
      self.encrypted_password = BCrypt::Password.create(password)
    end
  end
end
