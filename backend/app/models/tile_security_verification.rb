class TileSecurityVerification < ApplicationRecord
  belongs_to :layer
  belongs_to :admin_user
  validates :source_version, presence: true
  validates :status, inclusion: {in: %w[pending passed failed stale]}
end
