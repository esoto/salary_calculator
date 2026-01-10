# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    # Year selection with validation
    selected_year = params[:year].to_i
    selected_year = Date.current.year unless (2020..2100).cover?(selected_year)
    @selected_year = selected_year

    # Available years for dropdown
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse

    # YTD entries (use selected_year instead of current_year)
    ytd_entries = current_user.salary_entries.for_year(@selected_year)

    # Aguinaldo period entries
    aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(@selected_year)

    # Summary stats (using SQL aggregation for performance)
    @months_logged = ytd_entries.count
    @total_earnings = ytd_entries.sum("hours_worked * hourly_rate")

    # Vacation/holiday savings and spent
    @vacation_savings = ytd_entries.sum("#{SalaryCalculations::VACATION_HOURS_PER_MONTH} * hourly_rate")
    @vacation_spent = ytd_entries.sum("COALESCE(vacation_days_taken, 0) * #{SalaryCalculations::HOURS_PER_DAY} * hourly_rate")
    @vacation_balance = @vacation_savings - @vacation_spent

    @holiday_savings = ytd_entries.sum("#{SalaryCalculations::HOLIDAY_HOURS_PER_MONTH} * hourly_rate")
    @holiday_spent = ytd_entries.sum("COALESCE(holiday_days_taken, 0) * #{SalaryCalculations::HOURS_PER_DAY} * hourly_rate")
    @holiday_balance = @holiday_savings - @holiday_spent

    @aguinaldo_savings = aguinaldo_entries.sum("hours_worked * hourly_rate / 12.0")

    # Days earned and taken
    @vacation_days_earned = @months_logged * SalaryCalculations::VACATION_DAYS_PER_MONTH
    @vacation_days_taken = ytd_entries.sum(:vacation_days_taken)
    @vacation_days_available = @vacation_days_earned - @vacation_days_taken

    @holiday_days_earned = @months_logged * SalaryCalculations::HOLIDAY_DAYS_PER_MONTH
    @holiday_days_taken = ytd_entries.sum(:holiday_days_taken)
    @holiday_days_available = @holiday_days_earned - @holiday_days_taken

    # Total savings and net pay (YTD)
    ytd_aguinaldo = ytd_entries.sum("hours_worked * hourly_rate / 12.0")
    @total_savings = ytd_aguinaldo + @vacation_balance + @holiday_balance
    @net_pay = @total_earnings - @total_savings

    # Recent entries
    @recent_entries = current_user.salary_entries.order(year: :desc, month: :desc).limit(5)

    @current_year = @selected_year
  end
end
