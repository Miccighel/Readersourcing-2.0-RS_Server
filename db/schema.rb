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

ActiveRecord::Schema[8.1].define(version: 2026_10_05_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "authentication_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "jti", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_authentication_tokens_on_expires_at"
    t.index ["jti"], name: "index_authentication_tokens_on_jti", unique: true
    t.index ["user_id"], name: "index_authentication_tokens_on_user_id"
  end

  create_table "publications", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.string "creator"
    t.string "doi"
    t.string "pdf_download_path"
    t.string "pdf_download_path_link"
    t.string "pdf_name"
    t.string "pdf_name_link"
    t.string "pdf_storage_path"
    t.string "pdf_url"
    t.string "producer"
    t.decimal "score_rsm", default: "0.0"
    t.decimal "score_trm", default: "0.0"
    t.decimal "steadiness", default: "0.0"
    t.string "subject"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "ratings", force: :cascade do |t|
    t.decimal "accuracy_loss", default: "0.0"
    t.boolean "anonymous", default: false
    t.decimal "bonus", default: "0.0"
    t.datetime "created_at", null: false
    t.boolean "edited", default: false
    t.decimal "goodness", default: "0.0"
    t.decimal "informativeness", default: "0.0"
    t.integer "original_score", null: false
    t.bigint "publication_id"
    t.integer "score", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["publication_id"], name: "index_ratings_on_publication_id"
    t.index ["user_id", "publication_id"], name: "index_ratings_on_user_id_and_publication_id", unique: true
    t.index ["user_id"], name: "index_ratings_on_user_id"
    t.check_constraint "original_score >= 0 AND original_score <= 100", name: "ratings_original_score_range"
    t.check_constraint "score >= 0 AND score <= 100", name: "ratings_score_range"
  end

  create_table "users", force: :cascade do |t|
    t.decimal "bonus", default: "0.0"
    t.string "confirm_token"
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "email_confirmed", default: false
    t.string "first_name"
    t.string "last_name"
    t.string "orcid"
    t.string "password_digest"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.decimal "score", default: "0.000001"
    t.decimal "steadiness", default: "0.0"
    t.boolean "subscribe", default: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "authentication_tokens", "users", on_delete: :cascade
  add_foreign_key "ratings", "publications"
  add_foreign_key "ratings", "users"
end
