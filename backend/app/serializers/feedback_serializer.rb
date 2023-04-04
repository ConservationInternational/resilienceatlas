# == Schema Information
#
# Table name: feedbacks
#
#  id         :bigint           not null, primary key
#  language   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class FeedbackSerializer < ActiveModel::Serializer
  attributes :language, :created_at, :updated_at
  has_many :feedback_fields
end
