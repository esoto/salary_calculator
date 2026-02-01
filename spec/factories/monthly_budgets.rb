FactoryBot.define do
  factory :monthly_budget do
    user
    year { Date.current.year }
    sequence(:month) { |n| ((n - 1) % 12) + 1 }
    exchange_rate { 503.0 }
  end
end
