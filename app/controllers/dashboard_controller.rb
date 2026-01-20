# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
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

    # Summary stats (using SQL aggregation for performance)
    @months_logged = @ytd_entries.count
    @total_earnings = @ytd_entries.sum("hours_worked * hourly_rate")

    # Vacation/holiday savings and spent
    @vacation_savings = @ytd_entries.sum("#{SalaryCalculations::VACATION_HOURS_PER_MONTH} * hourly_rate")
    @vacation_spent = @ytd_entries.sum("COALESCE(vacation_days_taken, 0) * #{SalaryCalculations::HOURS_PER_DAY} * hourly_rate")
    @vacation_balance = @vacation_savings - @vacation_spent

    @holiday_savings = @ytd_entries.sum("#{SalaryCalculations::HOLIDAY_HOURS_PER_MONTH} * hourly_rate")
    @holiday_spent = @ytd_entries.sum("COALESCE(holiday_days_taken, 0) * #{SalaryCalculations::HOURS_PER_DAY} * hourly_rate")
    @holiday_balance = @holiday_savings - @holiday_spent

    @aguinaldo_savings = aguinaldo_entries.sum("hours_worked * hourly_rate / 12.0")

    # Days earned and taken
    @vacation_days_earned = @months_logged * SalaryCalculations::VACATION_DAYS_PER_MONTH
    @vacation_days_taken = @ytd_entries.sum(:vacation_days_taken)
    @vacation_days_available = @vacation_days_earned - @vacation_days_taken

    @holiday_days_earned = @months_logged * SalaryCalculations::HOLIDAY_DAYS_PER_MONTH
    @holiday_days_taken = @ytd_entries.sum(:holiday_days_taken)
    @holiday_days_available = @holiday_days_earned - @holiday_days_taken

    # Total savings and net pay (YTD)
    ytd_aguinaldo = @ytd_entries.sum("hours_worked * hourly_rate / 12.0")
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

    categories = {
      "Aguinaldo" => :aguinaldo_savings,
      "Vacation" => :vacation_savings,
      "Holiday" => :holiday_savings
    }

    categories.each_with_object({}) do |(name, method), result|
      result[name] = (1..12).map do |month|
        month_label = Date::MONTHNAMES[month][0..2]
        entry = entries_by_month[month]&.first
        value = entry ? entry.send(method).to_f : 0
        [ month_label, value ]
      end
    end
  end
end
