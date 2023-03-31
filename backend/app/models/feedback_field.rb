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
class FeedbackField < ApplicationRecord
  belongs_to :feedback
  belongs_to :parent, class_name: "FeedbackField", optional: true

  has_many :children, class_name: "FeedbackField", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  enum :feedback_field_type, {
    boolean_choice: "boolean_choice",
    single_choice: "single_choice",
    multiple_choice: "multiple_choice",
    free_answer: "free_answer",
    rating: "rating"
  }, default: :single_choice, _suffix: true

  validates :answer, json: true

  before_validation :set_feedback

  accepts_nested_attributes_for :children, allow_destroy: true

  private

  def set_feedback
    self.feedback ||= parent.feedback if parent.present?
  end
end
