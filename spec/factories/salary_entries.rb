FactoryBot.define do
  factory :salary_entry do
    month { 1 }
    year { 2025 }
    hours_worked { 160.0 }
    hourly_rate { 50.0 }
  end
end
