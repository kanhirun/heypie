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

ActiveRecord::Schema.define(version: 2018_09_04_003331) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "contribution_approval_requests", force: :cascade do |t|
    t.integer "submitter_id"
  end

  create_table "grunts", force: :cascade do |t|
    t.string "name"
    t.integer "slices_of_pie"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "nominations", force: :cascade do |t|
    t.integer "grunt_id"
    t.integer "contribution_approval_request_id"
    t.integer "slices_of_pie_to_be_rewarded"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "votes", force: :cascade do |t|
    t.integer "grunt_id"
    t.integer "contribution_approval_request_id"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "contribution_approval_requests", "grunts", column: "submitter_id"
end
