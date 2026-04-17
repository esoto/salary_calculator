class CreateIncomeSourceOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :income_source_overrides do |t|
      t.references :income_source,
                   null: false,
                   foreign_key: { on_delete: :cascade },
                   index: false
      t.integer :year,  null: false
      t.integer :month, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :scope, null: false
      t.timestamps
    end

    add_index :income_source_overrides,
              [ :income_source_id, :year, :month, :scope ],
              unique: true,
              name: "idx_income_overrides_unique"

    add_check_constraint :income_source_overrides,
                         "month BETWEEN 1 AND 12",
                         name: "chk_ioo_month_range"
    add_check_constraint :income_source_overrides,
                         "year BETWEEN 2020 AND 2100",
                         name: "chk_ioo_year_range"
    add_check_constraint :income_source_overrides,
                         "amount >= 0",
                         name: "chk_ioo_amount_nonneg"
  end
end
