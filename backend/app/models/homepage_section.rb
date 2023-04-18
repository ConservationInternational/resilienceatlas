# == Schema Information
#
# Table name: homepage_sections
#
#  id                :bigint           not null, primary key
#  homepage_id       :bigint           not null
#  button_url        :string
#  image_position    :string
#  image_credits_url :string
#  background_color  :string
#  position          :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string
#  subtitle          :string
#  button_text       :string
#  image_credits     :string
#
class HomepageSection < ApplicationRecord
  belongs_to :homepage

  has_one_attached :image, service: :local_public

  enum :image_position, {left: "left", right: "right", cover: "cover"}, default: :left, prefix: true

  translates :title, :subtitle, :button_text, :image_credits, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :title, :subtitle, :button_text, :image_credits

  translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }
  translation_class.validates_presence_of :subtitle, if: -> { locale.to_s == I18n.default_locale.to_s }

  validates :button_url, url: true
  validates :image_credits_url, url: true
  validates :position, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :image_position, presence: true
  validates :image, presence: true, content_type: /\Aimage\/.*\z/
end
