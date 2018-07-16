class ModelSerializer < ActiveModel::Serializer
  cache key: "model"
  attributes :name, :description, :source
  has_many :site_scopes, each_serializer: SiteScopeSerializer
  has_many :indicators, each_serializer: IndicatorSerializer
end
