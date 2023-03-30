# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  slug        :string           not null
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class CategorySerializer < ActiveModel::Serializer
  cache key: "category"
  attributes :name, :slug, :description
  has_many :indicators, each_serializer: ModelSerializer
end
