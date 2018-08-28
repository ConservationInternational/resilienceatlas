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

class Indicator < ActiveRecord::Base
  has_and_belongs_to_many :models
  belongs_to :category

  validates_presence_of :slug
  validates_presence_of :name
  validates_presence_of :position

  acts_as_list scope: :category


  def self.fetch_all(options={})
    Indicator.all
  end
end
