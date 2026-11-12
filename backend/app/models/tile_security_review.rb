class TileSecurityReview < ApplicationRecord
  belongs_to :layer
  belongs_to :admin_user
  validates :reason, :source_version, presence: true
  validates :reason, :resolution, length: {maximum: 1000}
  validates :status, inclusion: {in: %w[pending approved rejected stale]}
end
