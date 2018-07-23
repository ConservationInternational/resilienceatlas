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
    if options[:site_scope]
      site_scope = options[:site_scope].to_i
      return Model.joins(:site_scopes)
               .where('models_site_scopes.site_scope_id = ?', site_scope)
    else
      return Model.all
    end
  end
end
