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

class SitePage < ActiveRecord::Base
    belongs_to :site_scope
    validates_uniqueness_of :title, scope: :site_scope_id
end
