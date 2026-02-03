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

  def budget_owner_label(budget)
    return nil if budget.owned_by?(current_user)

    "#{budget.user.name}'s Budget"
  end

  def budget_shared_badge
    content_tag(:span, "🏠 Shared", class: "text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded")
  end

  def activity_description(version)
    case version.item_type
    when "MonthlyBudget"
      budget_activity_description(version)
    when "BudgetItem"
      budget_item_activity_description(version)
    else
      "Unknown activity"
    end
  end

  def activity_actor_name(version, current_user)
    return "You" if version.whodunnit == current_user.id.to_s

    user = User.find_by(id: version.whodunnit)
    user&.name || "Someone"
  end

  def activity_time_ago(version)
    time_ago_in_words(version.created_at) + " ago"
  end

  private

  def budget_activity_description(version)
    case version.event
    when "create"
      "created this budget"
    when "update"
      changes = parse_version_changes(version)
      if changes.key?("exchange_rate")
        old_rate, new_rate = changes["exchange_rate"]
        "changed exchange rate from #{old_rate.to_i} to #{new_rate.to_i}"
      elsif changes.key?("shared_with_household")
        changes["shared_with_household"][1] ? "shared this budget with household" : "made this budget private"
      else
        "updated this budget"
      end
    when "destroy"
      "deleted this budget"
    else
      "modified this budget"
    end
  end

  def budget_item_activity_description(version)
    item_name = extract_item_name(version)

    case version.event
    when "create"
      amount = extract_item_amount(version)
      "added \"#{item_name}\" ($#{amount})"
    when "update"
      changes = parse_version_changes(version)
      if changes.key?("amount")
        old_amount, new_amount = changes["amount"]
        "changed \"#{item_name}\" $#{old_amount} → $#{new_amount}"
      elsif changes.key?("paid")
        changes["paid"][1] ? "marked \"#{item_name}\" as paid" : "marked \"#{item_name}\" as unpaid"
      else
        "updated \"#{item_name}\""
      end
    when "destroy"
      "removed \"#{item_name}\""
    else
      "modified \"#{item_name}\""
    end
  end

  def extract_item_amount(version)
    changes = parse_version_changes(version)
    changes.dig("amount", 1) || version.item&.amount
  end

  def parse_version_changes(version)
    return {} unless version.object_changes.present?

    YAML.safe_load(
      version.object_changes,
      permitted_classes: [ BigDecimal, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Time ],
      aliases: true
    ).except("updated_at", "created_at")
  rescue StandardError
    {}
  end

  def extract_item_name(version)
    if version.event == "destroy"
      version.reify&.name || "item"
    else
      version.item&.name || version.reify&.name || "item"
    end
  end
end
