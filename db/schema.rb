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

ActiveRecord::Schema[8.0].define(version: 2026_01_06_231544) do
  create_table "salary_entries", force: :cascade do |t|
    t.integer "month", null: false
    t.integer "year", null: false
    t.decimal "hours_worked", precision: 10, scale: 2, null: false
    t.decimal "hourly_rate", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["month", "year"], name: "index_salary_entries_on_month_and_year", unique: true
  end
end
