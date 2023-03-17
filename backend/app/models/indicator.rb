# == Schema Information
#
# Table name: indicators
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  version     :string
#  created_at  :datetime         default(Wed, 22 Feb 2023 12:02:20.466026000 CET +01:00), not null
#  updated_at  :datetime         default(Wed, 22 Feb 2023 12:02:20.474090000 CET +01:00), not null
#  category_id :integer
#  position    :integer
#  column_name :string
#  operation   :string
#  name        :string
#

class Indicator < ApplicationRecord
  has_and_belongs_to_many :models
  belongs_to :category

  translates :name, fallbacks_for_empty_translations: true
  active_admin_translates :name

  validates_presence_of :slug
  validates_presence_of :position
  translation_class.validates_presence_of :name, if: -> { locale.to_s == I18n.default_locale.to_s }

  acts_as_list scope: :category

  def self.fetch_all(options = {})
    Indicator.with_translations I18n.locale
  end
end
