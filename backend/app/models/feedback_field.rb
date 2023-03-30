class FeedbackField < ApplicationRecord
  belongs_to :feedback
  belongs_to :parent, class_name: "FeedbackField", optional: true

  has_many :children, class_name: "FeedbackField", foreign_key: :parent_id, dependent: :destroy

  enum :feedback_field_type, {
    boolean_choice: "boolean_choice",
    single_choice: "single_choice",
    multiple_choice: "multiple_choice",
    free_answer: "free_answer",
    rating: "rating"
  }, default: :single_choice, _suffix: true

  validates :answers, json: true

  accepts_nested_attributes_for :children, allow_destroy: true
end
