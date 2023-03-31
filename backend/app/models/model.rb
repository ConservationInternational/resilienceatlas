# == Schema Information
#
# Table name: models
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         default(Wed, 22 Feb 2023 12:02:20.403696000 CET +01:00), not null
#  updated_at     :datetime         default(Wed, 22 Feb 2023 12:02:20.453249000 CET +01:00), not null
#  query_analysis :text
#  table_name     :string
#  name           :string
#  description    :text
#  source         :text
#

class Model < ApplicationRecord
  has_and_belongs_to_many :site_scopes
  has_and_belongs_to_many :indicators

  translates :name, :description, :source, fallbacks_for_empty_translations: true
  active_admin_translates :name, :description, :source

  translation_class.validates_presence_of :name, if: -> { locale.to_s == I18n.default_locale.to_s }

  def self.fetch_all(options = {})
    if options[:site_scope]
      site_scope = options[:site_scope].to_i
      Model.joins(:site_scopes)
        .where("models_site_scopes.site_scope_id = ?", site_scope)
    else
      Model.all
    end
  end
end
