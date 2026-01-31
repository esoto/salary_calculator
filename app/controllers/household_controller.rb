class HouseholdController < ApplicationController
  before_action :require_household_membership

  def show
    @household = Current.user.household

    @available_years = SalaryEntry.where(user: @household.members)
                                  .distinct.pluck(:year).sort.reverse

    @selected_year = if params[:year].present? && (2020..2100).cover?(params[:year].to_i)
                        params[:year].to_i
    else
                        @available_years.first || Date.current.year
    end

    @combined_earnings = @household.combined_earnings_for_year(@selected_year)
    @combined_savings = @household.combined_savings_for_year(@selected_year)
    @member_stats = @household.member_stats_for_year(@selected_year)
    @savings_chart_data = prepare_household_chart_data(@selected_year)
  end

  private

  def require_household_membership
    unless Current.user.household.present?
      redirect_to dashboard_path, alert: "You are not a member of a household."
    end
  end

  # Loads entries into memory because savings calculations are computed Ruby methods
  # (aguinaldo_savings, vacation_savings, holiday_savings depend on user settings).
  # Scale is small: ~2-3 members × 12 months = ~36 records max per year.
  def prepare_household_chart_data(year)
    entries = SalaryEntry.where(user: @household.members).for_year(year)
    entries_by_user = entries.group_by(&:user_id)

    @household.members.map do |member|
      member_entries = entries_by_user[member.id] || []
      entries_by_month = member_entries.group_by(&:month)

      series_data = (1..12).map do |month|
        month_label = Date::MONTHNAMES[month][0..2]
        entry = entries_by_month[month]&.first
        value = entry ? (entry.aguinaldo_savings + entry.vacation_savings + entry.holiday_savings).to_f : 0
        [ month_label, value ]
      end

      { name: member.name, data: series_data }
    end
  end
end
