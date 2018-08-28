# == Schema Information
#
# Table name: indicators
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  slug        :string           not null
#  version     :string
#  created_at  :datetime         default(Wed, 01 Aug 2018 18:56:01 CEST +02:00), not null
#  updated_at  :datetime         default(Wed, 01 Aug 2018 18:56:01 CEST +02:00), not null
#  category_id :integer
#  position    :integer
#  column_name :string
#  operation   :string
#

class IndicatorSerializer < ActiveModel::Serializer
  cache key: "indicator"
  attributes :name, :slug, :version, :position, :column_name, :operation
  has_many :models, each_serializer: ModelSerializer
  has_one :category, serializer: CategorySerializer
end
