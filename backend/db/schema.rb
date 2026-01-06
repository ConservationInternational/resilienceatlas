# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_07_02_120000) do
  create_schema "topology"

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"
  enable_extension "postgis_topology"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.boolean "allow_password_change", default: false
    t.string "name"
    t.string "nickname"
    t.string "image"
    t.json "tokens"
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "agrupations", force: :cascade do |t|
    t.bigint "layer_id"
    t.bigint "layer_group_id"
    t.boolean "active", default: false
    t.index ["layer_group_id"], name: "index_agrupations_on_layer_group_id"
    t.index ["layer_id"], name: "index_agrupations_on_layer_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "category_translations", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "description"
    t.index ["category_id"], name: "index_category_translations_on_category_id"
    t.index ["locale"], name: "index_category_translations_on_locale"
  end

  create_table "ckeditor_assets", force: :cascade do |t|
    t.string "data_file_name", null: false
    t.string "data_content_type"
    t.integer "data_file_size"
    t.string "data_fingerprint"
    t.integer "assetable_id"
    t.string "assetable_type", limit: 30
    t.string "type", limit: 30
    t.integer "width"
    t.integer "height"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type"
  end

  create_table "feedback_fields", force: :cascade do |t|
    t.bigint "feedback_id", null: false
    t.bigint "parent_id"
    t.string "feedback_field_type", null: false
    t.string "question"
    t.jsonb "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feedback_id"], name: "index_feedback_fields_on_feedback_id"
    t.index ["parent_id"], name: "index_feedback_fields_on_parent_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.string "language", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "homepage_journey_translations", force: :cascade do |t|
    t.bigint "homepage_journey_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.index ["homepage_journey_id"], name: "index_homepage_journey_translations_on_homepage_journey_id"
    t.index ["locale"], name: "index_homepage_journey_translations_on_locale"
  end

  create_table "homepage_journeys", force: :cascade do |t|
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "homepage_section_translations", force: :cascade do |t|
    t.bigint "homepage_section_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "subtitle"
    t.string "button_text"
    t.string "image_credits"
    t.index ["homepage_section_id"], name: "index_homepage_section_translations_on_homepage_section_id"
    t.index ["locale"], name: "index_homepage_section_translations_on_locale"
  end

  create_table "homepage_sections", force: :cascade do |t|
    t.bigint "homepage_id", null: false
    t.string "button_url"
    t.string "image_position"
    t.string "image_credits_url"
    t.string "background_color"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["homepage_id"], name: "index_homepage_sections_on_homepage_id"
  end

  create_table "homepage_translations", force: :cascade do |t|
    t.bigint "homepage_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "subtitle"
    t.string "credits"
    t.index ["homepage_id"], name: "index_homepage_translations_on_homepage_id"
    t.index ["locale"], name: "index_homepage_translations_on_locale"
  end

  create_table "homepages", force: :cascade do |t|
    t.bigint "homepage_journey_id"
    t.bigint "site_scope_id", null: false
    t.string "credits_url"
    t.boolean "show_journeys", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["homepage_journey_id"], name: "index_homepages_on_homepage_journey_id"
    t.index ["site_scope_id"], name: "index_homepages_on_site_scope_id", unique: true
  end

  create_table "identities", force: :cascade do |t|
    t.bigint "user_id"
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "indicator_translations", force: :cascade do |t|
    t.bigint "indicator_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["indicator_id"], name: "index_indicator_translations_on_indicator_id"
    t.index ["locale"], name: "index_indicator_translations_on_locale"
  end

  create_table "indicators", force: :cascade do |t|
    t.string "slug", null: false
    t.string "version"
    t.datetime "created_at", precision: nil, default: "2026-01-06 18:12:25", null: false
    t.datetime "updated_at", precision: nil, default: "2026-01-06 18:12:25", null: false
    t.integer "category_id"
    t.integer "position"
    t.string "column_name"
    t.string "operation"
    t.index ["slug"], name: "index_indicators_on_slug"
  end

  create_table "indicators_models", id: false, force: :cascade do |t|
    t.bigint "indicator_id", null: false
    t.bigint "model_id", null: false
  end

  create_table "journey_step_translations", force: :cascade do |t|
    t.bigint "journey_step_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "subtitle"
    t.string "description"
    t.text "content"
    t.string "credits"
    t.string "source"
    t.index ["journey_step_id"], name: "index_journey_step_translations_on_journey_step_id"
    t.index ["locale"], name: "index_journey_step_translations_on_locale"
  end

  create_table "journey_steps", force: :cascade do |t|
    t.string "step_type", null: false
    t.string "credits_url"
    t.string "mask_sql"
    t.string "map_url"
    t.string "embedded_map_url"
    t.string "background_color"
    t.integer "chapter_number"
    t.integer "position", default: 1, null: false
    t.bigint "journey_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journey_id"], name: "index_journey_steps_on_journey_id"
  end

  create_table "journey_translations", force: :cascade do |t|
    t.bigint "journey_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "subtitle"
    t.text "theme"
    t.string "credits"
    t.index ["journey_id"], name: "index_journey_translations_on_journey_id"
    t.index ["locale"], name: "index_journey_translations_on_locale"
  end

  create_table "journeys", force: :cascade do |t|
    t.string "credits_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published", default: false, null: false
  end

  create_table "layer_group_translations", force: :cascade do |t|
    t.bigint "layer_group_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "info"
    t.index ["layer_group_id", "locale"], name: "index_layer_group_translations_on_layer_group_id_and_locale", unique: true
    t.index ["layer_group_id"], name: "index_layer_group_translations_on_layer_group_id"
  end

  create_table "layer_groups", force: :cascade do |t|
    t.integer "super_group_id"
    t.string "slug"
    t.string "layer_group_type"
    t.string "category"
    t.boolean "active"
    t.integer "order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon_class"
    t.integer "site_scope_id", default: 1
    t.index ["site_scope_id"], name: "index_layer_groups_on_site_scope_id"
    t.index ["super_group_id"], name: "index_layer_groups_on_super_group_id"
  end

  create_table "layer_translations", force: :cascade do |t|
    t.bigint "layer_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "info"
    t.text "legend"
    t.string "title"
    t.string "data_units"
    t.string "processing"
    t.text "description"
    t.text "analysis_text_template"
    t.index ["layer_id", "locale"], name: "index_layer_translations_on_layer_id_and_locale", unique: true
    t.index ["layer_id"], name: "index_layer_translations_on_layer_id"
  end

  create_table "layers", force: :cascade do |t|
    t.integer "layer_group_id"
    t.string "slug", null: false
    t.string "layer_type"
    t.integer "zindex"
    t.boolean "active"
    t.integer "order"
    t.string "color"
    t.string "layer_provider"
    t.text "css"
    t.text "interactivity"
    t.float "opacity"
    t.text "query"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "locate_layer", default: false
    t.string "icon_class"
    t.boolean "published", default: true
    t.integer "zoom_max", default: 100
    t.integer "zoom_min", default: 0
    t.integer "dashboard_order"
    t.boolean "download", default: false
    t.string "dataset_shortname"
    t.text "dataset_source_url"
    t.string "title"
    t.datetime "start_date", precision: nil
    t.datetime "end_date", precision: nil
    t.string "spatial_resolution"
    t.string "spatial_resolution_units"
    t.string "temporal_resolution"
    t.string "temporal_resolution_units"
    t.string "update_frequency"
    t.string "version"
    t.boolean "analysis_suitable", default: false
    t.text "analysis_query"
    t.text "layer_config"
    t.text "analysis_body"
    t.text "interaction_config"
    t.boolean "timeline", default: false
    t.date "timeline_steps", default: [], array: true
    t.date "timeline_start_date"
    t.date "timeline_end_date"
    t.date "timeline_default_date"
    t.string "timeline_period"
    t.string "analysis_type"
    t.index ["layer_group_id"], name: "index_layers_on_layer_group_id"
  end

  create_table "layers_sources", id: false, force: :cascade do |t|
    t.integer "layer_id"
    t.integer "source_id"
    t.index ["layer_id"], name: "index_layers_sources_on_layer_id"
    t.index ["source_id"], name: "index_layers_sources_on_source_id"
  end

  create_table "map_menu_entries", force: :cascade do |t|
    t.string "link"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ancestry"
    t.index ["ancestry"], name: "index_map_menu_entries_on_ancestry"
  end

  create_table "map_menu_entry_translations", force: :cascade do |t|
    t.bigint "map_menu_entry_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label"
    t.index ["locale"], name: "index_map_menu_entry_translations_on_locale"
    t.index ["map_menu_entry_id"], name: "index_map_menu_entry_translations_on_map_menu_entry_id"
  end

  create_table "model_translations", force: :cascade do |t|
    t.bigint "model_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "description"
    t.text "source"
    t.index ["locale"], name: "index_model_translations_on_locale"
    t.index ["model_id"], name: "index_model_translations_on_model_id"
  end

  create_table "models", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: "2026-01-06 18:12:25", null: false
    t.datetime "updated_at", precision: nil, default: "2026-01-06 18:12:25", null: false
    t.text "query_analysis"
    t.string "table_name"
  end

  create_table "models_site_scopes", id: false, force: :cascade do |t|
    t.bigint "model_id", null: false
    t.bigint "site_scope_id", null: false
  end

  create_table "photos", force: :cascade do |t|
    t.text "image_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "share_urls", force: :cascade do |t|
    t.string "uid"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "site_page_translations", force: :cascade do |t|
    t.bigint "site_page_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "body"
    t.index ["locale"], name: "index_site_page_translations_on_locale"
    t.index ["site_page_id"], name: "index_site_page_translations_on_site_page_id"
  end

  create_table "site_pages", force: :cascade do |t|
    t.integer "priority"
    t.integer "site_scope_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["site_scope_id"], name: "index_site_pages_on_site_scope_id"
    t.index ["slug"], name: "index_site_pages_on_slug", unique: true
  end

  create_table "site_scope_translations", force: :cascade do |t|
    t.bigint "site_scope_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.text "linkback_text"
    t.index ["locale"], name: "index_site_scope_translations_on_locale"
    t.index ["site_scope_id"], name: "index_site_scope_translations_on_site_scope_id"
  end

  create_table "site_scopes", force: :cascade do |t|
    t.string "color"
    t.string "subdomain"
    t.boolean "has_analysis", default: false
    t.float "latitude"
    t.float "longitude"
    t.string "header_theme"
    t.integer "zoom_level", default: 3
    t.text "linkback_url"
    t.string "header_color"
    t.text "logo_url"
    t.boolean "predictive_model", default: false, null: false
    t.boolean "analysis_options", default: false, null: false
    t.boolean "has_gef_logo"
    t.boolean "password_protected", default: false, null: false
    t.string "username"
    t.string "encrypted_password"
    t.index ["password_protected"], name: "index_site_scopes_on_password_protected"
  end

  create_table "source_translations", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reference"
    t.string "reference_short"
    t.string "license"
    t.index ["locale"], name: "index_source_translations_on_locale"
    t.index ["source_id"], name: "index_source_translations_on_source_id"
  end

  create_table "sources", force: :cascade do |t|
    t.string "source_type"
    t.string "url"
    t.string "contact_name"
    t.string "contact_email"
    t.datetime "last_updated", precision: nil
    t.string "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "spatial_resolution_units"
    t.text "license_url"
  end

  create_table "static_page_base_translations", force: :cascade do |t|
    t.bigint "static_page_base_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.string "image_credits"
    t.index ["locale"], name: "index_static_page_base_translations_on_locale"
    t.index ["static_page_base_id"], name: "index_static_page_base_translations_on_static_page_base_id"
  end

  create_table "static_page_bases", force: :cascade do |t|
    t.string "slug", null: false
    t.string "image_credits_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_static_page_bases_on_slug", unique: true
  end

  create_table "static_page_section_item_translations", force: :cascade do |t|
    t.bigint "static_page_section_item_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.text "description"
    t.index ["locale"], name: "index_static_page_section_item_translations_on_locale"
    t.index ["static_page_section_item_id"], name: "index_fa4aaafd643913512d32f726a2d5386348fe26b9"
  end

  create_table "static_page_section_items", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id"], name: "index_static_page_section_items_on_section_id"
  end

  create_table "static_page_section_paragraph_translations", force: :cascade do |t|
    t.bigint "static_page_section_paragraph_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "text"
    t.string "image_credits"
    t.index ["locale"], name: "index_static_page_section_paragraph_translations_on_locale"
    t.index ["static_page_section_paragraph_id"], name: "index_f17c96ce33322e20078393ba2050031b69c21daa"
  end

  create_table "static_page_section_paragraphs", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.string "image_position", null: false
    t.string "image_credits_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id"], name: "index_static_page_section_paragraphs_on_section_id"
  end

  create_table "static_page_section_reference_translations", force: :cascade do |t|
    t.bigint "static_page_section_reference_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "text"
    t.index ["locale"], name: "index_static_page_section_reference_translations_on_locale"
    t.index ["static_page_section_reference_id"], name: "index_20a5e4f35f4caac5967f343864093a95839d0632"
  end

  create_table "static_page_section_references", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.string "slug"
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id"], name: "index_static_page_section_references_on_section_id"
  end

  create_table "static_page_section_translations", force: :cascade do |t|
    t.bigint "static_page_section_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
    t.index ["locale"], name: "index_static_page_section_translations_on_locale"
    t.index ["static_page_section_id"], name: "index_5003c0227599fab8954262af0e37841ad7785126"
  end

  create_table "static_page_sections", force: :cascade do |t|
    t.bigint "static_page_id", null: false
    t.integer "position", null: false
    t.string "slug"
    t.string "section_type", null: false
    t.integer "title_size", default: 2
    t.boolean "show_at_navigation", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["static_page_id"], name: "index_static_page_sections_on_static_page_id"
  end

  create_table "user_downloads", force: :cascade do |t|
    t.string "subdomain"
    t.integer "user_id"
    t.integer "layer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.string "organization"
    t.string "organization_role"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agrupations", "layer_groups"
  add_foreign_key "agrupations", "layers"
  add_foreign_key "feedback_fields", "feedback_fields", column: "parent_id", on_delete: :cascade
  add_foreign_key "feedback_fields", "feedbacks", on_delete: :cascade
  add_foreign_key "homepage_sections", "homepages", on_delete: :cascade
  add_foreign_key "homepages", "homepage_journeys", on_delete: :nullify
  add_foreign_key "homepages", "site_scopes", on_delete: :cascade
  add_foreign_key "identities", "users"
  add_foreign_key "indicators", "categories"
  add_foreign_key "journey_steps", "journeys", on_delete: :cascade
  add_foreign_key "layer_group_translations", "layer_groups"
  add_foreign_key "layer_translations", "layers"
  add_foreign_key "static_page_section_items", "static_page_sections", column: "section_id", on_delete: :cascade
  add_foreign_key "static_page_section_paragraphs", "static_page_sections", column: "section_id", on_delete: :cascade
  add_foreign_key "static_page_section_references", "static_page_sections", column: "section_id", on_delete: :cascade
  add_foreign_key "static_page_sections", "static_page_bases", column: "static_page_id", on_delete: :cascade
end
