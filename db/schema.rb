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

ActiveRecord::Schema[7.1].define(version: 2026_04_14_082820) do
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "insee", null: false
    t.string "nom_com", null: false
    t.float "latitude"
    t.float "longitude"
    t.string "cv"
    t.string "nom_cv"
    t.string "dep"
    t.string "nom_dep"
    t.string "reg"
    t.string "nom_reg"
    t.string "libgeo"
    t.string "paysage"
    t.float "APL2023"
    t.integer "code_qual"
    t.float "avg_price_sqm"
    t.float "median_price_sqm"
    t.integer "total_transactions"
    t.integer "transactions_last_year"
    t.float "chom_24"
    t.integer "population"
    t.float "population_density"
    t.integer "count_coll"
    t.integer "count_ecol"
    t.integer "count_lyce"
    t.integer "nb_comm"
    t.integer "nb_cultu"
    t.integer "nb_com_ali"
    t.integer "nb_gd_surf"
    t.integer "nb_loisirs"
    t.integer "nb_sport"
    t.integer "nb_creche"
    t.float "BUS_valeur"
    t.float "BUS_val_1"
    t.float "TRAIN_valeur"
    t.float "TRAIN_val_1"
    t.float "METRO_valeur"
    t.float "METRO_val_1"
    t.float "TRAM_valeur"
    t.float "TRAM_val_1"
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
    t.float "price_evolution_1y"
    t.float "price_evolution_3y"
    t.float "leisures_sports_score"
    t.float "first_deg_score"
    t.float "second_deg_score"
    t.string "code_posta"
    t.float "nb_obs_commune"
    t.float "avg_rent_sqm"
    t.float "rent_quality"
  end

  create_table "guest_searches", force: :cascade do |t|
    t.string "research_name"
    t.boolean "coast"
    t.boolean "mountain"
    t.integer "density"
    t.boolean "no_filters"
    t.integer "real_estate", default: 0
    t.integer "near_big_city", default: 0
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
    t.string "chosen_nearest_big_city"
    t.string "education_1"
    t.string "education_2"
    t.string "education_3"
    t.string "education_4"
    t.string "education_5"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "leisures_and_sports", default: 0
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
    t.integer "density"
    t.boolean "no_filters"
    t.integer "real_estate", default: 0
    t.integer "near_big_city", default: 0
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "chosen_nearest_big_city"
    t.integer "leisures_and_sports", default: 0
    t.string "education_levels", default: [], array: true
    t.string "leisure_levels", default: [], array: true
    t.index ["user_id"], name: "index_researches_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
