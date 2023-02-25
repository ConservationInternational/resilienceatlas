# == Schema Information
#
# Table name: models
#
#  id             :bigint           not null, primary key
#  name           :string           not null
#  description    :text
#  source         :text
#  created_at     :datetime         default(Wed, 22 Feb 2023 12:02:20.403696000 CET +01:00), not null
#  updated_at     :datetime         default(Wed, 22 Feb 2023 12:02:20.453249000 CET +01:00), not null
#  query_analysis :text
#  table_name     :string
#

class Model < ApplicationRecord
  has_and_belongs_to_many :site_scopes
  has_and_belongs_to_many :indicators

  validates_presence_of :name

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
