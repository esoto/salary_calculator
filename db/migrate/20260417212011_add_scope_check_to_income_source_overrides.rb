class AddScopeCheckToIncomeSourceOverrides < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :income_source_overrides,
                         "scope IN ('single_month', 'from_this_month')",
                         name: "chk_ioo_scope_valid"
  end
end
