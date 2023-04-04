# == Schema Information
#
# Table name: models
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         default(Tue, 28 Mar 2023 22:07:16.745569000 CEST +02:00), not null
#  updated_at     :datetime         default(Tue, 28 Mar 2023 22:07:16.746270000 CEST +02:00), not null
#  query_analysis :text
#  table_name     :string
#  name           :string
#  description    :text
#  source         :text
#

class Model < ApplicationRecord
  has_and_belongs_to_many :site_scopes
  has_and_belongs_to_many :indicators

  translates :name, :description, :source, touch: true, fallbacks_for_empty_translations: true
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
