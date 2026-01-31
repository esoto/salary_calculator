FactoryBot.define do
  factory :monthly_budget do
    user
    year { 2026 }
    sequence(:month) { |n| ((n - 1) % 12) + 1 }
    exchange_rate { 503.0 }
  end
end
