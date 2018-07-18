# == Schema Information
#
# Table name: indicators
#
#  id                :integer          not null, primary key
#  name              :string           not null
#  slug              :string           not null
#  version           :string
#  analysis_suitable :boolean          default(FALSE)
#  analysis_query    :text
#

class Indicator < ActiveRecord::Base
  has_and_belongs_to_many :models

  validates_presence_of :slug
  validates_presence_of :name


  def self.fetch_all(options={})
    Indicator.all
  end
end
