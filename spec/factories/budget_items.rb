FactoryBot.define do
  factory :budget_item do
    monthly_budget
    name { "Test Expense" }
    category { "fixed" }
    amount { 100.00 }
    currency { "USD" }
    paid { false }
  end
end
