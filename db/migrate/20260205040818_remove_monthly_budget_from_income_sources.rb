class RemoveMonthlyBudgetFromIncomeSources < ActiveRecord::Migration[8.1]
  def change
    remove_reference :income_sources, :monthly_budget, foreign_key: true
  end
end
