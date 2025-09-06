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
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :name, :description, touch: true, fallbacks_for_empty_translations: true
  end

  has_and_belongs_to_many :layers

  translates :reference, :reference_short, :license, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :reference, :reference_short, :license

  # Override attributes method to handle Globalize translations properly
  def attributes
    # Get the base attributes from ActiveRecord
    base_attrs = super
    
    # Add translated attributes if they exist
    if respond_to?(:translated_attributes) && translated_attributes.present?
      base_attrs.merge!(translated_attributes)
    end
    
    base_attrs
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id source_type reference reference_short url contact_name contact_email license last_updated version created_at updated_at spatial_resolution_units license_url]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[layers translations]
  end
end
