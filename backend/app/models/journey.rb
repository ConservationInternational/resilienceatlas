class Journey < ApplicationRecord
  has_many :journey_steps, dependent: :destroy

  has_one_attached :background_image, service: :local_public

  translates :title, :subtitle, :theme
  active_admin_translates :title, :subtitle, :theme

  accepts_nested_attributes_for :journey_steps, allow_destroy: true
end
