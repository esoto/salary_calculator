# frozen_string_literal: true

module ApplicationHelper
  def format_usd(amount)
    number_to_currency(amount, precision: CurrencyPrecision::CURRENCY_DECIMAL_PLACES)
  end

  def format_crc(amount)
    number_to_currency(amount, unit: "₡", precision: 0, delimiter: ",")
  end

  def budget_item_form_id(budget_item, category)
    budget_item.persisted? ? dom_id(budget_item, :form) : "item_form_#{category}"
  end

  def nav_link_class(path)
    if current_page?(path)
      "text-blue-600 font-semibold"
    else
      "text-gray-600 hover:text-gray-800"
    end
  end
end
