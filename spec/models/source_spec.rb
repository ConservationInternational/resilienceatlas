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

require 'rails_helper'

RSpec.describe Source, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
