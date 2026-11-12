class TileSecurityEvent < ApplicationRecord
  belongs_to :layer, optional: true
  belongs_to :admin_user, optional: true
  validates :action, :reason, presence: true
  validates :reason, length: {maximum: 1000}
end
