class AddMonthlyBudgetToIncomeSources < ActiveRecord::Migration[8.1]
  def change
    add_reference :income_sources, :monthly_budget, foreign_key: true
  end
end
