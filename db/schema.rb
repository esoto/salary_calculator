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

ActiveRecord::Schema[8.1].define(version: 2026_01_27_013653) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "household_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "household_id", null: false
    t.datetime "joined_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["household_id"], name: "index_household_memberships_on_household_id"
    t.index ["user_id"], name: "index_household_memberships_on_user_id", unique: true
  end

  create_table "households", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "invite_code", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_code"], name: "index_households_on_invite_code", unique: true
  end

  create_table "salary_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "holiday_days_taken", precision: 4, scale: 2, default: "0.0", null: false
    t.decimal "hourly_rate", precision: 10, scale: 2, null: false
    t.decimal "hours_worked", precision: 10, scale: 2, null: false
    t.integer "month", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.decimal "vacation_days_taken", precision: 4, scale: 2, default: "0.0", null: false
    t.integer "year", null: false
    t.index ["month", "year", "user_id"], name: "index_salary_entries_on_month_and_year_and_user_id", unique: true
    t.index ["user_id"], name: "index_salary_entries_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "aguinaldo_enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.decimal "default_hourly_rate", precision: 10, scale: 2
    t.string "email_address", null: false
    t.integer "holiday_days_per_year", default: 10, null: false
    t.boolean "holiday_enabled", default: true, null: false
    t.integer "hours_per_day", default: 8, null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "vacation_days_per_year", default: 18, null: false
    t.boolean "vacation_enabled", default: true, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "household_memberships", "households"
  add_foreign_key "household_memberships", "users"
  add_foreign_key "salary_entries", "users"
  add_foreign_key "sessions", "users"
end
