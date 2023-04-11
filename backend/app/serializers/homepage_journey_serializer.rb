# == Schema Information
#
# Table name: homepage_journeys
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  title      :string
#
class HomepageJourneySerializer < ActiveModel::Serializer
  attributes :title, :position
end
