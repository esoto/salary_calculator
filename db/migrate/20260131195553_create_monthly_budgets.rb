class CreateMonthlyBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_budgets do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.decimal :exchange_rate, precision: 10, scale: 4, null: false

      t.timestamps
    end

    add_index :monthly_budgets, [ :user_id, :year, :month ], unique: true
  end
end
