class AddUserToSalaryEntries < ActiveRecord::Migration[8.0]
  def change
    add_reference :salary_entries, :user, null: false, foreign_key: true

    # Update unique index to include user_id
    remove_index :salary_entries, [:month, :year]
    add_index :salary_entries, [:month, :year, :user_id], unique: true
  end
end
