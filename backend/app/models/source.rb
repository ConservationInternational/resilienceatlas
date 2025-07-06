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
end
