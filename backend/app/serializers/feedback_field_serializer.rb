# == Schema Information
#
# Table name: feedback_fields
#
#  id                  :bigint           not null, primary key
#  feedback_id         :bigint           not null
#  parent_id           :bigint
#  feedback_field_type :string           not null
#  question            :string
#  answer              :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class FeedbackFieldSerializer < ActiveModel::Serializer
  attributes :feedback_field_type, :question, :answer, :created_at, :updated_at
  belongs_to :feedback
  belongs_to :parent, serializer: FeedbackFieldSerializer
  has_many :children, serializer: FeedbackFieldSerializer
end
