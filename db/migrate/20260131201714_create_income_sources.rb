class CreateIncomeSources < ActiveRecord::Migration[8.1]
  def change
    create_table :income_sources do |t|
      t.references :user, null: false, foreign_key: true
      t.references :linked_user, null: true, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.decimal :amount, precision: 12, scale: 2
      t.string :currency, null: false, default: "USD"
      t.string :income_type, null: false, default: "fixed"
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
