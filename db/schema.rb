# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20151024110910) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admin_users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "admin_users", ["email"], name: "index_admin_users_on_email", unique: true, using: :btree
  add_index "admin_users", ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true, using: :btree

  create_table "agrupations", force: :cascade do |t|
    t.integer "layer_id"
    t.integer "layer_group_id"
  end

  add_index "agrupations", ["layer_group_id"], name: "index_agrupations_on_layer_group_id", using: :btree
  add_index "agrupations", ["layer_id"], name: "index_agrupations_on_layer_id", using: :btree

  create_table "layer_groups", force: :cascade do |t|
    t.string   "name"
    t.integer  "super_group_id"
    t.string   "slug"
    t.string   "layer_group_type"
    t.string   "category"
    t.boolean  "active"
    t.integer  "order"
    t.text     "info"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "icon_class"
    t.integer  "site_scope_id"
  end

  add_index "layer_groups", ["site_scope_id"], name: "index_layer_groups_on_site_scope_id", using: :btree
  add_index "layer_groups", ["super_group_id"], name: "index_layer_groups_on_super_group_id", using: :btree

  create_table "layers", force: :cascade do |t|
    t.string   "name",                           null: false
    t.string   "slug",                           null: false
    t.string   "layer_type"
    t.integer  "zindex"
    t.boolean  "active"
    t.integer  "order"
    t.string   "color"
    t.text     "info"
    t.string   "layer_provider"
    t.text     "css"
    t.text     "interactivity"
    t.float    "opacity"
    t.text     "query"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.boolean  "locate_layer",   default: false
    t.string   "icon_class"
    t.boolean  "published",      default: true
    t.text     "legend"
    t.integer  "zoom_max",       default: 100
    t.integer  "zoom_min",       default: 0
    t.integer  "layer_group_id"
  end

  create_table "share_urls", force: :cascade do |t|
    t.string   "uid"
    t.text     "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "site_scopes", force: :cascade do |t|
    t.string "name", default: "global"
  end

  add_foreign_key "agrupations", "layer_groups"
  add_foreign_key "agrupations", "layers"
end
