# frozen_string_literal: true

module BudgetsHelper
  def category_display_name(category)
    MonthlyBudget::CATEGORY_DISPLAY_NAMES[category] || category.humanize
  end

  def category_target_range(category)
    target = MonthlyBudget::CATEGORY_TARGETS[category]
    return nil unless target

    if target[:min] == target[:max]
      "#{target[:min]}%"
    else
      "#{target[:min]}-#{target[:max]}%"
    end
  end

  def category_status_color(status)
    case status
    when :ok then "text-green-600"
    when :warning then "text-yellow-600"
    when :low, :high then "text-red-600"
    else "text-gray-600"
    end
  end

  def category_status_bg(status)
    case status
    when :ok then "bg-green-100"
    when :warning then "bg-yellow-100"
    when :low, :high then "bg-red-100"
    else "bg-gray-100"
    end
  end

  def category_status_icon(status)
    case status
    when :ok then "✓"
    when :warning then "⚠"
    when :low then "↓"
    when :high then "↑"
    else ""
    end
  end

  def month_options_for_select
    (1..12).map { |m| [ Date::MONTHNAMES[m], m ] }
  end

  def year_options_for_select(range: 5)
    current_year = Date.current.year
    ((current_year - range)..(current_year + 1)).to_a.reverse
  end
end
