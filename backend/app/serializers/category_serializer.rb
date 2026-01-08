# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  name        :string
#  description :text
#

class CategorySerializer < ActiveModel::Serializer
  cache key: "category_#{I18n.locale}"
  attributes :name, :slug, :description
  has_many :indicators, each_serializer: ModelSerializer
end
