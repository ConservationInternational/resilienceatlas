# == Schema Information
#
# Table name: sources
#
#  id                       :bigint           not null, primary key
#  source_type              :string
#  reference                :string
#  reference_short          :string
#  url                      :string
#  contact_name             :string
#  contact_email            :string
#  license                  :string
#  last_updated             :datetime
#  version                  :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  spatial_resolution_units :string
#  license_url              :text
#

class Source < ApplicationRecord
  has_and_belongs_to_many :layers

  # Only translate the fields that actually exist in the translation table
  translates :reference, :reference_short, :license, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :reference, :reference_short, :license

  def self.ransackable_attributes(auth_object = nil)
    %w[id source_type reference reference_short url contact_name contact_email license last_updated version created_at updated_at spatial_resolution_units license_url]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[layers translations]
  end

  # Override attributes method to properly handle Globalize translations
  # Fixes "undefined method 'name' for Translation" errors in tests
  def attributes
    attrs = super
    if self.class.translates?
      # Merge translated attributes with base attributes
      translated_attrs = translated_attributes || {}
      attrs.merge!(translated_attrs.stringify_keys) if translated_attrs.respond_to?(:stringify_keys)
    end
    attrs
  end
end
