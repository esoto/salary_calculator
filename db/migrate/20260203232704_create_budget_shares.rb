class CreateBudgetShares < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_shares do |t|
      t.references :monthly_budget, null: false, foreign_key: true
      t.string :token, null: false
      t.string :name
      t.boolean :show_budget, default: true, null: false
      t.boolean :show_income_sources, default: false, null: false
      t.boolean :show_personal_savings, default: false, null: false
      t.datetime :expires_at

      t.timestamps
    end

    add_index :budget_shares, :token, unique: true
  end
end
