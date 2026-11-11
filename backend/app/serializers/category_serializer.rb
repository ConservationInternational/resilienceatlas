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
  attributes :name, :slug, :description
  has_many :indicators, each_serializer: IndicatorSerializer

  def indicators
    object.indicators.joins(models: :site_scopes)
      .where(site_scopes: {id: instance_options[:site_scope]}).distinct
  end
end
