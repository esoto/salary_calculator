FactoryBot.define do
  factory :salary_entry do
    user
    month { 1 }
    year { 2025 }
    hours_worked { 160.0 }
    hourly_rate { 50.0 }
    vacation_days_taken { 0 }
    holiday_days_taken { 0 }
  end
end
