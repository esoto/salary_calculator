class AddBankFeeEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :bank_fee_enabled, :boolean, default: false, null: false
  end
end
