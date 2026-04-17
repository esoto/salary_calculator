FactoryBot.define do
  factory :income_source_override do
    income_source
    year  { 2026 }
    month { 4 }
    amount { 1500.00 }
    scope { "single_month" }
  end
end
