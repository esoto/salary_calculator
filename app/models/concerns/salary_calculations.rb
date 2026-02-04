# frozen_string_literal: true

module SalaryCalculations
  extend ActiveSupport::Concern

  def monthly_salary
    hours_worked * hourly_rate
  end

  def aguinaldo_savings
    return 0 unless user.aguinaldo_enabled
    monthly_salary / 12.0
  end

  def vacation_savings
    return 0 unless user.vacation_enabled
    vacation_hours_per_month * hourly_rate
  end

  def holiday_savings
    return 0 unless user.holiday_enabled
    holiday_hours_per_month * hourly_rate
  end

  def monthly_savings_accrual
    aguinaldo_savings + vacation_savings + holiday_savings
  end

  def total_savings
    aguinaldo_savings + vacation_balance + holiday_balance
  end

  def net_pay
    monthly_salary - total_savings
  end

  def vacation_spent
    (vacation_days_taken || 0) * user.hours_per_day * hourly_rate
  end

  def holiday_spent
    (holiday_days_taken || 0) * user.hours_per_day * hourly_rate
  end

  def vacation_balance
    vacation_savings - vacation_spent
  end

  def holiday_balance
    holiday_savings - holiday_spent
  end

  private

  def vacation_hours_per_month
    (user.vacation_days_per_year * user.hours_per_day) / 12.0
  end

  def holiday_hours_per_month
    (user.holiday_days_per_year * user.hours_per_day) / 12.0
  end

  def vacation_days_per_month
    user.vacation_days_per_year / 12.0
  end

  def holiday_days_per_month
    user.holiday_days_per_year / 12.0
  end
end
