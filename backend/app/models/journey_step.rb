class JourneyStep < ApplicationRecord
  AVAILABLE_FIELDS_FOR_EVERY_TYPE = { # dont forget to add/remove fields to/from Admin and API
    title: {available_at: %i[landing conclusion chapter]},
    subtitle: {available_at: %i[landing]},
    theme: {available_at: %i[landing]},
    content: {available_at: %i[conclusion chapter embed]},
    chapter_number: {available_at: %i[chapter]},
    credits: {available_at: %i[landing conclusion chapter]},
    credits_url: {available_at: %i[landing conclusion chapter]},
    map_theme: {available_at: %i[embed]},
    mask_sql: {available_at: %i[embed]},
    map_url: {available_at: %i[embed]},
    btn_url: {available_at: %i[embed]},
    position: {available_at: %i[landing conclusion chapter embed]},
    background_color: {available_at: %i[conclusion]},
    background_image: {available_at: %i[landing conclusion chapter]}
  }.freeze

  belongs_to :journey

  has_rich_text :content

  has_one_attached :background_image, service: :local_public

  enum :step_type, {landing: "landing", conclusion: "conclusion", chapter: "chapter", embed: "embed"}, default: :landing

  translates :title, :subtitle, :theme, :content
  active_admin_translates :title, :subtitle, :theme, :content
end
