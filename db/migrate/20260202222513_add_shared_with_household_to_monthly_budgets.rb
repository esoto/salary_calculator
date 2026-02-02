class AddSharedWithHouseholdToMonthlyBudgets < ActiveRecord::Migration[8.1]
  def change
    add_column :monthly_budgets, :shared_with_household, :boolean, default: false, null: false
  end
end
