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
#  slug          :string
#

class SitePage < ActiveRecord::Base
    belongs_to :site_scope
    validates_uniqueness_of :title, scope: :site_scope_id
    validates_presence_of :title, :site_scope, :body, :slug
    validates_uniqueness_of :slug
end
