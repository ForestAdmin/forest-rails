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

ActiveRecord::Schema.define(version: 20190716135241) do

  create_table "isle", force: :cascade do |t|
    t.string   "name"
    t.binary   "map"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "trees", force: :cascade do |t|
    t.string   "name"
    t.integer  "owner_id"
    t.integer  "cutter_id"
    t.integer  "island_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "age"
  end

  add_index "trees", ["cutter_id"], name: "index_trees_on_cutter_id"
  add_index "trees", ["island_id"], name: "index_trees_on_island_id"
  add_index "trees", ["owner_id"], name: "index_trees_on_owner_id"

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "title"
  end

end
