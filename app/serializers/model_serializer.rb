# == Schema Information
#
# Table name: models
#
#  id             :integer          not null, primary key
#  name           :string           not null
#  description    :text
#  source         :text
#  created_at     :datetime         default(Wed, 01 Aug 2018 18:56:01 CEST +02:00), not null
#  updated_at     :datetime         default(Wed, 01 Aug 2018 18:56:01 CEST +02:00), not null
#  query_analysis :text
#  table_name     :string
#

class ModelSerializer < ActiveModel::Serializer
  cache key: "model"
  attributes :name, :description, :source, :query_analysis, :table_name
  has_many :site_scopes, each_serializer: SiteScopeSerializer
  has_many :indicators, each_serializer: IndicatorSerializer
end
