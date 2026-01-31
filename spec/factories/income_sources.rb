FactoryBot.define do
  factory :income_source do
    user
    name { "Main Income" }
    amount { 5000.00 }
    currency { "USD" }
    income_type { "fixed" }
    active { true }
  end
end
