class AddTimeOffToSalaryEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :salary_entries, :vacation_days_taken, :decimal, precision: 4, scale: 2, default: 0, null: false
    add_column :salary_entries, :holiday_days_taken, :decimal, precision: 4, scale: 2, default: 0, null: false
  end
end
