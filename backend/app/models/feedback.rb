# == Schema Information
#
# Table name: feedbacks
#
#  id         :bigint           not null, primary key
#  language   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Feedback < ApplicationRecord
  has_many :feedback_fields, dependent: :destroy

  validates_presence_of :language

  accepts_nested_attributes_for :feedback_fields, allow_destroy: true
end
