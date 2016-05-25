# == Schema Information
#
# Table name: site_pages
#
#  id            :integer          not null, primary key
#  title         :string
#  body          :text
#  priority      :integer
#  site_scope_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

require 'rails_helper'

RSpec.describe SitePage, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
