class CreateSalaryEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :salary_entries do |t|
      t.integer :month, null: false
      t.integer :year, null: false
      t.decimal :hours_worked, precision: 10, scale: 2, null: false
      t.decimal :hourly_rate, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :salary_entries, [:month, :year], unique: true
  end
end
