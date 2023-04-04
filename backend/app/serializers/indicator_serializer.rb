# == Schema Information
#
# Table name: indicators
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  version     :string
#  created_at  :datetime         default(Tue, 28 Mar 2023 22:07:16.747487000 CEST +02:00), not null
#  updated_at  :datetime         default(Tue, 28 Mar 2023 22:07:16.747956000 CEST +02:00), not null
#  category_id :integer
#  position    :integer
#  column_name :string
#  operation   :string
#  name        :string
#

class IndicatorSerializer < ActiveModel::Serializer
  cache key: "indicator_#{I18n.locale}"
  attributes :name, :slug, :version, :position, :column_name, :operation
  has_many :models, each_serializer: ModelSerializer
  has_one :category, serializer: CategorySerializer
end
