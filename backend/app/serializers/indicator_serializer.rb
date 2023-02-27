# == Schema Information
#
# Table name: indicators
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  slug        :string           not null
#  version     :string
#  created_at  :datetime         default(Wed, 22 Feb 2023 12:02:20.466026000 CET +01:00), not null
#  updated_at  :datetime         default(Wed, 22 Feb 2023 12:02:20.474090000 CET +01:00), not null
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
