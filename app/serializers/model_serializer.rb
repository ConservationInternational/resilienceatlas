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

class ModelSerializer < ActiveModel::Serializer
  cache key: "model"
  attributes :name, :description, :source, :query_analysis, :table_name
  has_many :site_scopes, each_serializer: SiteScopeSerializer
  has_many :indicators, each_serializer: IndicatorSerializer
end
