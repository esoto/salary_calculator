class CreateHouseholdMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :household_memberships do |t|
      t.references :household, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.datetime :joined_at, null: false

      t.timestamps
    end
  end
end
