module SalaryEntriesHelper
  def month_name(month)
    Date::MONTHNAMES[month]
  end

  # Delegates to format_usd in ApplicationHelper for consistency.
  # Kept for backwards compatibility with existing views.
  def format_currency(amount)
    format_usd(amount)
  end

  def format_hours(hours)
    number_with_precision(hours, precision: 2)
  end
end
