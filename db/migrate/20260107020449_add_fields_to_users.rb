class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string, null: false
    add_column :users, :default_hourly_rate, :decimal, precision: 10, scale: 2
  end
end
