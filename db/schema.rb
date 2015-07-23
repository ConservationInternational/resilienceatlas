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

ActiveRecord::Schema.define(version: 20150723114721) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
  end

  add_index "layer_groups", ["super_group_id"], name: "index_layer_groups_on_super_group_id", using: :btree

  create_table "layers", force: :cascade do |t|
    t.integer  "layer_group_id"
    t.string   "name",           null: false
    t.string   "slug",           null: false
    t.string   "layer_type"
    t.integer  "zindex"
    t.boolean  "active"
    t.integer  "order"
    t.string   "color"
    t.text     "info"
    t.text     "interactivity"
    t.float    "opacity"
    t.text     "query"
    t.string   "layer_provider"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "layers", ["layer_group_id"], name: "index_layers_on_layer_group_id", using: :btree

  create_table "share_urls", force: :cascade do |t|
    t.string   "uid"
    t.text     "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
