# == Schema Information
#
# Table name: sources
#
#  id              :integer          not null, primary key
#  source_type     :string
#  reference       :string
#  reference_short :string
#  url             :string
#  contact_name    :string
#  contact_email   :string
#  license         :string
#  last_updated    :datetime
#  version         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class Source < ActiveRecord::Base
  has_many :layers, inverse_of: :source
end
