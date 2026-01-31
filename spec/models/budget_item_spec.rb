require 'rails_helper'

RSpec.describe BudgetItem, type: :model do
  describe "validations" do
    it { should belong_to(:monthly_budget) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:category) }
    it { should validate_presence_of(:amount) }
    it { should validate_presence_of(:currency) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { should validate_inclusion_of(:category).in_array(%w[fixed guilt_free savings investments]) }
    it { should validate_inclusion_of(:currency).in_array(%w[CRC USD]) }
  end

  describe "#amount_in_usd" do
    let(:budget) { create(:monthly_budget, exchange_rate: 500) }

    it "returns amount directly for USD items" do
      item = create(:budget_item, monthly_budget: budget, amount: 100, currency: "USD")
      expect(item.amount_in_usd).to eq(100)
    end

    it "converts CRC to USD using exchange rate" do
      item = create(:budget_item, monthly_budget: budget, amount: 50000, currency: "CRC")
      expect(item.amount_in_usd).to eq(100)
    end
  end

  describe "#amount_in_crc" do
    let(:budget) { create(:monthly_budget, exchange_rate: 500) }

    it "returns amount directly for CRC items" do
      item = create(:budget_item, monthly_budget: budget, amount: 50000, currency: "CRC")
      expect(item.amount_in_crc).to eq(50000)
    end

    it "converts USD to CRC using exchange rate" do
      item = create(:budget_item, monthly_budget: budget, amount: 100, currency: "USD")
      expect(item.amount_in_crc).to eq(50000)
    end
  end
end
