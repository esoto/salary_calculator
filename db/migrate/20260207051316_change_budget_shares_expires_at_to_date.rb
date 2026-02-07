class ChangeBudgetSharesExpiresAtToDate < ActiveRecord::Migration[8.1]
  def change
    change_column :budget_shares, :expires_at, :date
  end
end
