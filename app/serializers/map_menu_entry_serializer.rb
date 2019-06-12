class MapMenuEntrySerializer < ActiveModel::Serializer
  attributes :id, :label, :link, :position, :ancestry
end
