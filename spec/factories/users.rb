FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }
    name { "Test User" }
    default_hourly_rate { 50.0 }
  end
end
