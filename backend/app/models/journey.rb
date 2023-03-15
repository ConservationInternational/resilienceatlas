# == Schema Information
#
# Table name: journeys
#
#  id          :bigint           not null, primary key
#  credits     :string
#  credits_url :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  published   :boolean          default(FALSE), not null
#  title       :string
#  subtitle    :string
#  theme       :text
#
class Journey < ApplicationRecord
  has_many :journey_steps, dependent: :destroy

  has_one_attached :background_image, service: :local_public

  translates :title, :subtitle, :theme, :credits
  active_admin_translates :title, :subtitle, :theme, :credits

  validates :background_image, content_type: /\Aimage\/.*\z/
  validates :credits_url, url: true

  accepts_nested_attributes_for :journey_steps, allow_destroy: true

  scope :only_published, -> { where published: true }
end
