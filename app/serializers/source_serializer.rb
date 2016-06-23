
class SourceSerializer < ActiveModel::Serializer
  cache key: "source"
  attributes :reference_short, :url
  def type
    'source'
  end
end
