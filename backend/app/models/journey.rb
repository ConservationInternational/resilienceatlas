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

  translates :title, :subtitle, :theme, :credits, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :title, :subtitle, :theme, :credits

  validates :background_image, content_type: /\Aimage\/.*\z/
  validates :credits_url, url: true

  after_save :at_least_one_step

  accepts_nested_attributes_for :journey_steps, allow_destroy: true

  scope :only_published, -> { where published: true }

  private

  # Validation of presence of relation(s) which is updated via nested attributes and contains translated attributes needs to be done
  # after save, otherwise the old translations are loaded from database at time of validation and they overwrite the new ones before they get saved.
  def at_least_one_step
    return if journey_steps.exists?

    errors.add :journey_steps, :blank
    raise ActiveRecord::Rollback
  end
end
