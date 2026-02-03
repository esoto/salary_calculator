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

ActiveRecord::Schema[8.1].define(version: 2026_02_03_032626) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "budget_items", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "CRC", null: false
    t.bigint "monthly_budget_id", null: false
    t.string "name", null: false
    t.boolean "paid", default: false, null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["monthly_budget_id", "category"], name: "index_budget_items_on_monthly_budget_id_and_category"
    t.index ["monthly_budget_id"], name: "index_budget_items_on_monthly_budget_id"
  end

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

  create_table "income_sources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "amount", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "income_type", default: "fixed", null: false
    t.bigint "linked_user_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["linked_user_id"], name: "index_income_sources_on_linked_user_id"
    t.index ["user_id"], name: "index_income_sources_on_user_id"
  end

  create_table "monthly_budgets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "exchange_rate", precision: 10, scale: 4, null: false
    t.integer "month", null: false
    t.boolean "shared_with_household", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "year", null: false
    t.index ["user_id", "year", "month"], name: "index_monthly_budgets_on_user_id_and_year_and_month", unique: true
    t.index ["user_id"], name: "index_monthly_budgets_on_user_id"
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

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "budget_items", "monthly_budgets"
  add_foreign_key "household_memberships", "households"
  add_foreign_key "household_memberships", "users"
  add_foreign_key "income_sources", "users"
  add_foreign_key "income_sources", "users", column: "linked_user_id"
  add_foreign_key "monthly_budgets", "users"
  add_foreign_key "salary_entries", "users"
  add_foreign_key "sessions", "users"
end
