require 'rails_helper'

RSpec.describe CurrencyPrecision do
  it "defines CURRENCY_DECIMAL_PLACES constant" do
    expect(CurrencyPrecision::CURRENCY_DECIMAL_PLACES).to eq(2)
  end

  it "defines PERCENTAGE_DECIMAL_PLACES constant" do
    expect(CurrencyPrecision::PERCENTAGE_DECIMAL_PLACES).to eq(2)
  end
end
