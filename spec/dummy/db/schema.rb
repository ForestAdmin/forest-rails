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

ActiveRecord::Schema.define(version: 2022_07_27_114930) do

  create_table "isle", force: :cascade do |t|
    t.string "name"
    t.binary "map"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "locations", force: :cascade do |t|
    t.string "coordinates"
    t.integer "island_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["island_id"], name: "index_locations_on_island_id"
  end

  create_table "manufacturers", force: :cascade do |t|
    t.string "name"
  end

  create_table "owners", force: :cascade do |t|
    t.string "name"
    t.datetime "hired_at"
  end

  create_table "products", force: :cascade do |t|
    t.string "uri"
    t.string "name"
    t.integer "manufacturer_id"
    t.integer "driver_id"
    t.index ["driver_id"], name: "index_products_on_driver_id"
    t.index ["manufacturer_id"], name: "index_products_on_manufacturer_id"
  end

  create_table "references", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "trees", force: :cascade do |t|
    t.string "name"
    t.integer "owner_id"
    t.integer "cutter_id"
    t.integer "island_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "age"
    t.index ["cutter_id"], name: "index_trees_on_cutter_id"
    t.index ["island_id"], name: "index_trees_on_island_id"
    t.index ["owner_id"], name: "index_trees_on_owner_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "title"
  end

end
