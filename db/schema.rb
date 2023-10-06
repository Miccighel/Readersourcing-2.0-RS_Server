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

ActiveRecord::Schema.define(version: 2018_07_18_090558) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "publications", force: :cascade do |t|
    t.string "doi"
    t.string "title"
    t.string "subject"
    t.string "author"
    t.string "creator"
    t.string "producer"
    t.string "pdf_url"
    t.string "pdf_storage_path"
    t.string "pdf_name"
    t.string "pdf_download_path"
    t.string "pdf_name_link"
    t.string "pdf_download_path_link"
    t.decimal "steadiness", default: "0.0"
    t.decimal "score_rsm", default: "0.0"
    t.decimal "score_trm", default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ratings", force: :cascade do |t|
    t.integer "score"
    t.integer "original_score"
    t.boolean "anonymous", default: false
    t.boolean "edited", default: false
    t.decimal "goodness", default: "0.0"
    t.decimal "informativeness", default: "0.0"
    t.decimal "accuracy_loss", default: "0.0"
    t.decimal "bonus", default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "publication_id"
    t.index ["publication_id"], name: "index_ratings_on_publication_id"
    t.index ["user_id"], name: "index_ratings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.boolean "email_confirmed", default: false
    t.string "confirm_token"
    t.string "orcid"
    t.boolean "subscribe", default: false
    t.string "password_digest"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.decimal "steadiness", default: "0.0"
    t.decimal "score", default: "0.000001"
    t.decimal "bonus", default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "ratings", "publications"
  add_foreign_key "ratings", "users"
end
