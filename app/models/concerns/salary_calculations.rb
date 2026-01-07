# frozen_string_literal: true

module SalaryCalculations
  extend ActiveSupport::Concern

  VACATION_DAYS = 18
  HOLIDAYS = 10
  HOURS_PER_DAY = 8
  MONTHS_PER_YEAR = 12

  VACATION_HOURS_PER_MONTH = (VACATION_DAYS * HOURS_PER_DAY) / MONTHS_PER_YEAR.to_f
  HOLIDAY_HOURS_PER_MONTH = (HOLIDAYS * HOURS_PER_DAY) / MONTHS_PER_YEAR.to_f
  VACATION_DAYS_PER_MONTH = VACATION_DAYS / MONTHS_PER_YEAR.to_f
  HOLIDAY_DAYS_PER_MONTH = HOLIDAYS / MONTHS_PER_YEAR.to_f

  def monthly_salary
    hours_worked * hourly_rate
  end

  def aguinaldo_savings
    monthly_salary / 12.0
  end

  def vacation_savings
    VACATION_HOURS_PER_MONTH * hourly_rate
  end

  def holiday_savings
    HOLIDAY_HOURS_PER_MONTH * hourly_rate
  end

  def total_savings
    aguinaldo_savings + vacation_savings + holiday_savings
  end

  def net_pay
    monthly_salary - total_savings
  end
end
