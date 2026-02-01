# frozen_string_literal: true

module ApplicationHelper
  def format_usd(amount)
    number_to_currency(amount, precision: 2)
  end

  def format_crc(amount)
    number_to_currency(amount, unit: "₡", precision: 0, delimiter: ",")
  end
end
