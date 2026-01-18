# == Schema Information
#
# Table name: layer_translations
#
#  id                     :bigint           not null, primary key
#  layer_id               :bigint           not null
#  locale                 :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  name                   :string
#  info                   :text
#  legend                 :text
#  title                  :string
#  data_units             :string
#  processing             :string
#  description            :text
#  analysis_text_template :text
#

class Layer::Translation < Globalize::ActiveRecord::Translation
  def self.ransackable_attributes(auth_object = nil)
    %w[
      analysis_text_template created_at data_units description id id_value
      info layer_id legend locale name processing title updated_at
    ]
  end
end
