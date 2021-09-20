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

FactoryBot.define do
  factory :site_page do
    title { "MyString" }
    body { "MyText" }
    priority { 1 }
  end

end
