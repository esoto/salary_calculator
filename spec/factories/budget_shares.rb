FactoryBot.define do
  factory :budget_share do
    monthly_budget
    show_budget { true }
    show_income_sources { false }
    show_personal_savings { false }
    expires_at { nil }
  end
end
