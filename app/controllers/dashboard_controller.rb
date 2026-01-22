# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    # Expose user for view conditionals
    @user = current_user

    # Available years for dropdown (needed for default selection)
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse

    # Year selection: use param if valid, otherwise default to most recent year with entries
    selected_year = params[:year].to_i
    if (2020..2100).cover?(selected_year)
      @selected_year = selected_year
    else
      @selected_year = @available_years.first || Date.current.year
    end

    # YTD entries (use selected_year instead of current_year)
    @ytd_entries = current_user.salary_entries.for_year(@selected_year)

    # Aguinaldo period entries
    aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(@selected_year)

    # Summary stats (using instance methods for user-specific settings)
    @months_logged = @ytd_entries.count
    @total_earnings = @ytd_entries.sum(&:monthly_salary)

    # Vacation/holiday savings and spent (user-specific calculations)
    @vacation_savings = @ytd_entries.sum(&:vacation_savings)
    @vacation_spent = @ytd_entries.sum(&:vacation_spent)
    @vacation_balance = @vacation_savings - @vacation_spent

    @holiday_savings = @ytd_entries.sum(&:holiday_savings)
    @holiday_spent = @ytd_entries.sum(&:holiday_spent)
    @holiday_balance = @holiday_savings - @holiday_spent

    @aguinaldo_savings = aguinaldo_entries.sum(&:aguinaldo_savings)

    # Days earned and taken (user-specific settings)
    @vacation_days_earned = @months_logged * (current_user.vacation_days_per_year / 12.0)
    @vacation_days_taken = @ytd_entries.sum(:vacation_days_taken)
    @vacation_days_available = @vacation_days_earned - @vacation_days_taken

    @holiday_days_earned = @months_logged * (current_user.holiday_days_per_year / 12.0)
    @holiday_days_taken = @ytd_entries.sum(:holiday_days_taken)
    @holiday_days_available = @holiday_days_earned - @holiday_days_taken

    # Total savings and net pay (YTD)
    ytd_aguinaldo = @ytd_entries.sum(&:aguinaldo_savings)
    @total_savings = ytd_aguinaldo + @vacation_balance + @holiday_balance
    @net_pay = @total_earnings - @total_savings

    # Recent entries
    @recent_entries = current_user.salary_entries.order(year: :desc, month: :desc).limit(5)

    @current_year = @selected_year

    # Prepare chart data
    @savings_chart_data = prepare_savings_chart_data(@ytd_entries)
  end

  private

  def prepare_savings_chart_data(ytd_entries)
    entries_by_month = ytd_entries.group_by(&:month)

    categories = {}
    categories["Aguinaldo"] = :aguinaldo_savings if current_user.aguinaldo_enabled
    categories["Vacation"] = :vacation_savings if current_user.vacation_enabled
    categories["Holiday"] = :holiday_savings if current_user.holiday_enabled

    categories.map do |name, method|
      series_data = (1..12).map do |month|
        month_label = Date::MONTHNAMES[month][0..2]
        entry = entries_by_month[month]&.first
        value = entry ? entry.send(method).to_f : 0
        [ month_label, value ]
      end
      { name: name, data: series_data }
    end
  end
end
