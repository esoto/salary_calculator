# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SalaryEntriesHelper, type: :helper do
  describe '#month_name' do
    it 'returns the full month name for valid month numbers' do
      expect(helper.month_name(1)).to eq('January')
      expect(helper.month_name(6)).to eq('June')
      expect(helper.month_name(12)).to eq('December')
    end

    it 'returns nil for month 0' do
      expect(helper.month_name(0)).to be_nil
    end

    it 'returns nil for month 13' do
      expect(helper.month_name(13)).to be_nil
    end
  end

  describe '#format_currency' do
    it 'formats amount as currency with 2 decimal precision' do
      expect(helper.format_currency(1000)).to eq('$1,000.00')
      expect(helper.format_currency(1234.56)).to eq('$1,234.56')
    end

    it 'handles zero' do
      expect(helper.format_currency(0)).to eq('$0.00')
    end

    it 'handles decimal values' do
      expect(helper.format_currency(666.67)).to eq('$666.67')
    end
  end

  describe '#format_hours' do
    it 'formats hours with 2 decimal precision' do
      expect(helper.format_hours(160)).to eq('160.00')
      expect(helper.format_hours(140.5)).to eq('140.50')
    end

    it 'handles zero' do
      expect(helper.format_hours(0)).to eq('0.00')
    end
  end
end
