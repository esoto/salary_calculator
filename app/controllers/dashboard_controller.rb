# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    current_year = Date.current.year

    # YTD entries
    ytd_entries = current_user.salary_entries.for_year(current_year)

    # Aguinaldo period entries
    aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(current_year)

    # Summary stats
    @months_logged = ytd_entries.count
    @total_earnings = ytd_entries.sum(&:monthly_salary)
    @vacation_savings = ytd_entries.sum(&:vacation_savings)
    @holiday_savings = ytd_entries.sum(&:holiday_savings)
    @aguinaldo_savings = aguinaldo_entries.sum(&:aguinaldo_savings)

    # Days earned (based on months logged)
    @vacation_days_earned = @months_logged * 1.5
    @holiday_days_earned = @months_logged * (10.0 / 12)

    # Recent entries
    @recent_entries = current_user.salary_entries.order(year: :desc, month: :desc).limit(5)

    @current_year = current_year
  end
end
