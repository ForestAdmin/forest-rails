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

ActiveRecord::Schema.define(version: 20160628173505) do

  create_table "belongs_to_class_name_fields", force: :cascade do |t|
    t.integer "foo_id"
  end

  add_index "belongs_to_class_name_fields", ["foo_id"], name: "index_belongs_to_class_name_fields_on_foo_id"

  create_table "belongs_to_fields", force: :cascade do |t|
    t.integer "has_one_field_id"
    t.integer "has_many_class_name_field_id"
    t.integer "has_many_field_id"
  end

  add_index "belongs_to_fields", ["has_many_class_name_field_id"], name: "index_belongs_to_fields_on_has_many_class_name_field_id"
  add_index "belongs_to_fields", ["has_many_field_id"], name: "index_belongs_to_fields_on_has_many_field_id"
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

  create_table "has_and_belongs_to_many_fields", force: :cascade do |t|
  end

  create_table "has_many_class_name_fields", force: :cascade do |t|
  end

  create_table "has_many_fields", force: :cascade do |t|
    t.integer "has_many_through_field_id"
  end

  add_index "has_many_fields", ["has_many_through_field_id"], name: "index_has_many_fields_on_has_many_through_field_id"

  create_table "has_many_through_fields", force: :cascade do |t|
  end

  create_table "has_one_fields", force: :cascade do |t|
  end

  create_table "integer_fields", force: :cascade do |t|
    t.integer "field"
  end

  create_table "owners", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "polymorphic_fields", force: :cascade do |t|
    t.integer "has_one_field_id"
  end

  add_index "polymorphic_fields", ["has_one_field_id"], name: "index_polymorphic_fields_on_has_one_field_id"

  create_table "string_fields", force: :cascade do |t|
    t.string "field"
  end

  create_table "trees", force: :cascade do |t|
    t.string   "name"
    t.integer  "owner_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "trees", ["owner_id"], name: "index_trees_on_owner_id"

end
