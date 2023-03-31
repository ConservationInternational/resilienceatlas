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

  translates :reference, :reference_short, :license, fallbacks_for_empty_translations: true
  active_admin_translates :reference, :reference_short, :license
end
