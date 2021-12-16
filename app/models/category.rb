# == Schema Information
#
# Table name: categories
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  slug        :string           not null
#  description :text
#  created_at  :datetime
#  updated_at  :datetime
#

class Category < ApplicationRecord
  has_many :indicators
  validates_presence_of :slug, :name

  def self.fetch_all(options={})
    Category.all
  end

end
