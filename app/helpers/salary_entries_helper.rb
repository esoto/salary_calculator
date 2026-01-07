module SalaryEntriesHelper
  def month_name(month)
    Date::MONTHNAMES[month]
  end

  def format_currency(amount)
    number_to_currency(amount, precision: 2)
  end

  def format_hours(hours)
    number_with_precision(hours, precision: 2)
  end
end
