# frozen_string_literal: true

module SharedBudgetsHelper
  def has_any_savings?(salary_entry)
    salary_entry.aguinaldo_savings.positive? ||
      salary_entry.vacation_savings.positive? ||
      salary_entry.holiday_savings.positive?
  end
end
