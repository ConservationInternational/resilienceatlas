# == Schema Information
#
# Table name: site_pages
#
#  id            :bigint           not null, primary key
#  title         :string
#  body          :text
#  priority      :integer
#  site_scope_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  slug          :string
#

class SitePageSerializer < ActiveModel::Serializer
  attributes :id, :title, :priority, :url
  def url
    "/contents/#{object.slug}"
  end
end
