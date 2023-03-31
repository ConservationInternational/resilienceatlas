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

class SitePage < ApplicationRecord
  belongs_to :site_scope

  has_rich_text :body

  translates :title, :body, fallbacks_for_empty_translations: true
  active_admin_translates :title, :body

  validates_presence_of :site_scope, :slug
  validates_uniqueness_of :slug
  translation_class.validates_presence_of :title, :body, if: -> { locale.to_s == I18n.default_locale.to_s }
end
