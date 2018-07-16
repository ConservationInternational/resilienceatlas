class IndicatorSerializer < ActiveModel::Serializer
  cache key: "indicator"
  attributes :name, :slug, :version, :analysis_suitable, :analysis_query
  has_many :models, each_serializer: ModelSerializer
end
