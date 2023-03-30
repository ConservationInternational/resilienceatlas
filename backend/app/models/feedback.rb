class Feedback < ApplicationRecord
  has_many :feedback_fields, dependent: :destroy

  validates_presence_of :language

  accepts_nested_attributes_for :feedback_fields, allow_destroy: true
end
