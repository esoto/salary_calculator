class ShareExistingHouseholdBudgets < ActiveRecord::Migration[8.1]
  def up
    # Set shared_with_household: true for all budgets where user is in a household
    # This preserves existing behavior where household members could access each other's budgets
    execute <<-SQL
      UPDATE monthly_budgets
      SET shared_with_household = true
      WHERE user_id IN (
        SELECT user_id FROM household_memberships
      )
    SQL
  end

  def down
    # Reset budgets for household users to not shared
    # Note: This won't perfectly restore state if users manually changed settings after migration
    execute <<-SQL
      UPDATE monthly_budgets
      SET shared_with_household = false
      WHERE user_id IN (
        SELECT user_id FROM household_memberships
      )
    SQL
  end
end
