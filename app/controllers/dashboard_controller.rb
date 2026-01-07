# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    current_year = Date.current.year

    # YTD entries
    ytd_entries = current_user.salary_entries.for_year(current_year)

    # Aguinaldo period entries
    aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(current_year)

    # Summary stats (using SQL aggregation for performance)
    @months_logged = ytd_entries.count
    @total_earnings = ytd_entries.sum("hours_worked * hourly_rate")
    @vacation_savings = ytd_entries.sum("#{SalaryCalculations::VACATION_HOURS_PER_MONTH} * hourly_rate")
    @holiday_savings = ytd_entries.sum("#{SalaryCalculations::HOLIDAY_HOURS_PER_MONTH} * hourly_rate")
    @aguinaldo_savings = aguinaldo_entries.sum("hours_worked * hourly_rate / 12.0")

    # Days earned (based on months logged)
    @vacation_days_earned = @months_logged * SalaryCalculations::VACATION_DAYS_PER_MONTH
    @holiday_days_earned = @months_logged * SalaryCalculations::HOLIDAY_DAYS_PER_MONTH

    # Recent entries
    @recent_entries = current_user.salary_entries.order(year: :desc, month: :desc).limit(5)

    @current_year = current_year
  end
end
