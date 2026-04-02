class AdminBoundary < ApplicationRecord
  validates :admin_level, presence: true, inclusion: {in: [0, 1, 2]}
  validates :geom, presence: true

  scope :countries, -> { where(admin_level: 0) }
  scope :provinces, -> { where(admin_level: 1) }
  scope :districts, -> { where(admin_level: 2) }
  scope :at_level, ->(level) { where("admin_level <= ?", level) }
end
