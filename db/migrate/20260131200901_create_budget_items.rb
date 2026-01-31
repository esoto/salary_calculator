class CreateBudgetItems < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_items do |t|
      t.references :monthly_budget, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "CRC"
      t.boolean :paid, null: false, default: false
      t.integer :position

      t.timestamps
    end

    add_index :budget_items, [:monthly_budget_id, :category]
  end
end
