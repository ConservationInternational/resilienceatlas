# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  name        :string
#  description :text
#

class Category < ApplicationRecord
  has_many :indicators

  translates :name, :description, fallbacks_for_empty_translations: true
  active_admin_translates :name, :description

  validates_presence_of :slug
  translation_class.validates_presence_of :name, if: -> { locale.to_s == I18n.default_locale.to_s }

  def self.fetch_all(options = {})
    Category.with_translations I18n.locale
  end
end
