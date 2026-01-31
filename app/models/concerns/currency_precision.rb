# frozen_string_literal: true

module CurrencyPrecision
  extend ActiveSupport::Concern

  CURRENCY_DECIMAL_PLACES = 2
  PERCENTAGE_DECIMAL_PLACES = 2
end
