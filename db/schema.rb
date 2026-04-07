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

ActiveRecord::Schema[7.1].define(version: 2026_04_07_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "chats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "city_name"
    t.float "latitude"
    t.float "longitude"
    t.string "real_estate_link"
    t.float "real_estate_score"
    t.float "nearest_big_city_score"
    t.float "job_market_score"
    t.float "transport_network_score"
    t.float "activities_score"
    t.float "living_cost_score"
    t.float "cultural_heritage_score"
    t.float "education_score"
    t.float "sunshine_score"
    t.float "outdoor_living_score"
    t.float "entertainment_score"
    t.float "health_score"
    t.float "commercial_life_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.text "content"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "point_of_interests", force: :cascade do |t|
    t.bigint "city_id", null: false
    t.string "name"
    t.float "latitude"
    t.float "longitude"
    t.string "kind"
    t.boolean "public", default: true
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id"], name: "index_point_of_interests_on_city_id"
  end

  create_table "researches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "research_name"
    t.boolean "coast"
    t.boolean "mountain"
    t.integer "density", default: 2000
    t.boolean "no_filters"
    t.integer "real_estate", default: 0
    t.integer "nearest_big_city", default: 0
    t.integer "job_market", default: 0
    t.integer "transport_network", default: 0
    t.integer "activities", default: 0
    t.integer "living_cost", default: 0
    t.integer "cultural_heritage", default: 0
    t.integer "education", default: 0
    t.integer "sunshine", default: 0
    t.integer "outdoor_living", default: 0
    t.integer "entertainment", default: 0
    t.integer "health", default: 0
    t.integer "commercial_life", default: 0
    t.string "activity_1"
    t.string "activity_2"
    t.string "activity_3"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_researches_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "firstname"
    t.string "lastname"
    t.datetime "date_of_birth"
    t.string "situation"
    t.boolean "single"
    t.text "relocation_project"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "chats", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "point_of_interests", "cities"
  add_foreign_key "researches", "users"
end
