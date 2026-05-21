# frozen_string_literal: true

class AiChatMessage < ApplicationRecord
  ROLES = %w[user agent].freeze

  belongs_to :admin_user

  validates :role,               inclusion: {in: ROLES}
  validates :content,            presence: true
  validates :bedrock_session_id, presence: true

  scope :recent, ->(n = 50) { order(created_at: :asc).last(n) }
end
