# == Schema Information
#
# Table name: models
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  description :text
#  source      :text
#

class Model < ActiveRecord::Base
  has_and_belongs_to_many :site_scopes
  has_and_belongs_to_many :indicators

  validates_presence_of :name

  def self.fetch_all(options={})
    Model.all
  end
end
