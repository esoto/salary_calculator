class AddSavingsSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :vacation_days_per_year, :integer, default: 18, null: false
    add_column :users, :holiday_days_per_year, :integer, default: 10, null: false
    add_column :users, :hours_per_day, :integer, default: 8, null: false
    add_column :users, :aguinaldo_enabled, :boolean, default: true, null: false
    add_column :users, :vacation_enabled, :boolean, default: true, null: false
    add_column :users, :holiday_enabled, :boolean, default: true, null: false
  end
end
