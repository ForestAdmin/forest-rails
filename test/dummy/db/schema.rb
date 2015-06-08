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

ActiveRecord::Schema.define(version: 20150608150016) do

  create_table "belongs_to_fields", force: :cascade do |t|
    t.integer "has_one_field_id"
  end

  add_index "belongs_to_fields", ["has_one_field_id"], name: "index_belongs_to_fields_on_has_one_field_id"

  create_table "boolean_fields", force: :cascade do |t|
    t.boolean "field"
  end

  create_table "date_fields", force: :cascade do |t|
    t.date "field"
  end

  create_table "decimal_fields", force: :cascade do |t|
    t.decimal "field"
  end

  create_table "float_fields", force: :cascade do |t|
    t.float "field"
  end

  create_table "has_many_fields", force: :cascade do |t|
  end

  create_table "has_one_fields", force: :cascade do |t|
  end

  create_table "integer_fields", force: :cascade do |t|
    t.integer "field"
  end

  create_table "string_fields", force: :cascade do |t|
    t.string "field"
  end

end
