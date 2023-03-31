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

class ModelSerializer < ActiveModel::Serializer
  cache key: "model_#{I18n.locale}"
  attributes :name, :description, :source, :query_analysis, :table_name
  has_many :site_scopes, each_serializer: SiteScopeSerializer
  has_many :indicators, each_serializer: IndicatorSerializer
end
