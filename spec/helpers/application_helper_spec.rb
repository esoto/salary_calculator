# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#format_usd' do
    it 'formats amount as USD currency with 2 decimal precision' do
      expect(helper.format_usd(1000)).to eq('$1,000.00')
      expect(helper.format_usd(1234.56)).to eq('$1,234.56')
    end

    it 'handles zero' do
      expect(helper.format_usd(0)).to eq('$0.00')
    end

    it 'handles decimal values' do
      expect(helper.format_usd(666.67)).to eq('$666.67')
    end

    it 'rounds to 2 decimal places' do
      expect(helper.format_usd(123.456)).to eq('$123.46')
    end
  end

  describe '#format_crc' do
    it 'formats amount as CRC currency with colon symbol and no decimals' do
      expect(helper.format_crc(1000)).to eq('₡1,000')
      expect(helper.format_crc(503000)).to eq('₡503,000')
    end

    it 'handles zero' do
      expect(helper.format_crc(0)).to eq('₡0')
    end

    it 'rounds to whole numbers' do
      expect(helper.format_crc(1234.56)).to eq('₡1,235')
    end
  end

  describe '#budget_item_form_id' do
    let(:budget) { create(:monthly_budget) }

    context 'with a persisted budget item' do
      let(:budget_item) { create(:budget_item, monthly_budget: budget, category: 'fixed') }

      it 'returns dom_id with form prefix' do
        expect(helper.budget_item_form_id(budget_item, 'fixed')).to eq("form_budget_item_#{budget_item.id}")
      end
    end

    context 'with a new budget item' do
      let(:budget_item) { build(:budget_item, monthly_budget: budget, category: 'savings') }

      it 'returns category-based form id' do
        expect(helper.budget_item_form_id(budget_item, 'savings')).to eq('item_form_savings')
      end

      it 'uses the passed category parameter' do
        expect(helper.budget_item_form_id(budget_item, 'guilt_free')).to eq('item_form_guilt_free')
      end
    end
  end
end
