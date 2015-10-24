# == Schema Information
#
# Table name: layers
#
#  id             :integer          not null, primary key
#  layer_group_id :integer
#  name           :string           not null
#  slug           :string           not null
#  layer_type     :string
#  zindex         :integer
#  active         :boolean
#  order          :integer
#  color          :string
#  info           :text
#  layer_provider :string
#  css            :text
#  interactivity  :text
#  opacity        :float
#  query          :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  locate_layer   :boolean          default(FALSE)
#  icon_class     :string
#  published      :boolean          default(TRUE)
#  legend         :text
#  zoom_max       :integer          default(100)
#  zoom_min       :integer          default(0)
#

class Layer < ActiveRecord::Base
  has_many :agrupations
  has_many :layer_groups, through: :agrupations
  accepts_nested_attributes_for :agrupations, :allow_destroy => true
  scope :site, -> (site) { joins(:layer_groups).where(layer_groups:{site_scope_id: site}) }
  def self.fetch_all(options={})
    if options[:site_scope] 
      site_scope = options[:site_scope].to_i
    else
      site_scope = 1
    end
    layers = Layer.all
    layers = layers.site(site_scope)
    layers
  end
end
