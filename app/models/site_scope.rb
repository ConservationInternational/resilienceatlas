# == Schema Information
#
# Table name: site_scopes
#
#  id   :integer          not null, primary key
#  name :string           default("global")
#

class SiteScope < ActiveRecord::Base
  has_many :layer_groups
end
