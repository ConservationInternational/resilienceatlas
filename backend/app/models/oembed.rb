class Oembed
  extend ActiveModel::Naming
  include ActiveModel::Model
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include ActiveModel::Serialization

  def initialize(attributes = {})
    self.attributes = attributes
  end

  def attributes=(attributes)
    @width = get_width(attributes[:width])
    @height = get_height(attributes[:height])
    @version = "1.0"
    @type = "rich"
    @provider_name = attributes[:provider_name]
    @provider_url = attributes[:provider_url]
  end

  attr_accessor :version, :type, :provider_name, :provider_url, :width, :height, :html

  def persisted?
    false
  end

  def get_width(value = nil)
    if value && value.to_i > 0
      value.to_i
    else
      960
    end
  end

  def get_height(value = nil)
    if value && value.to_i > 0
      value.to_i
    else
      600
    end
  end
end
