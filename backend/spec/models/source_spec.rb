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

require "rails_helper"

RSpec.describe Source, type: :model do
  let!(:source) { create :source }

  it "Source is valid" do
    expect(source).to be_valid
    expect(source.contact_email).to be_present
  end

  it "Count sources" do
    expect(Source.count).to eq(1)
  end
end
