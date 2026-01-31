require 'rails_helper'

RSpec.describe MonthlyBudget, type: :model do
  describe "validations" do
    it { should belong_to(:user) }
    it { should validate_presence_of(:year) }
    it { should validate_presence_of(:month) }
    it { should validate_presence_of(:exchange_rate) }
    it { should validate_numericality_of(:year).is_greater_than_or_equal_to(2020).is_less_than_or_equal_to(2100) }
    it { should validate_numericality_of(:month).is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12) }
    it { should validate_numericality_of(:exchange_rate).is_greater_than(0) }
  end

  describe "uniqueness" do
    let(:user) { create(:user) }
    let!(:existing_budget) { create(:monthly_budget, user: user, year: 2026, month: 1) }

    it "prevents duplicate budgets for same user/year/month" do
      duplicate = build(:monthly_budget, user: user, year: 2026, month: 1)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:month]).to include("has already been taken")
    end
  end

  describe "calculations" do
    let(:user) { create(:user) }
    let!(:income_source) { create(:income_source, user: user, amount: 5000, currency: "USD") }
    let(:budget) { create(:monthly_budget, user: user, exchange_rate: 500) }

    before do
      create(:budget_item, monthly_budget: budget, category: "fixed", amount: 1500, currency: "USD")
      create(:budget_item, monthly_budget: budget, category: "fixed", amount: 250000, currency: "CRC")
      create(:budget_item, monthly_budget: budget, category: "guilt_free", amount: 500, currency: "USD")
      create(:budget_item, monthly_budget: budget, category: "savings", amount: 400, currency: "USD")
      create(:budget_item, monthly_budget: budget, category: "investments", amount: 500, currency: "USD")
    end

    describe "#total_income_usd" do
      it "sums all active income sources in USD" do
        expect(budget.total_income_usd).to eq(5000)
      end
    end

    describe "#category_total_usd" do
      it "sums items in category, converting CRC to USD" do
        # 1500 USD + 250000 CRC / 500 = 1500 + 500 = 2000
        expect(budget.category_total_usd("fixed")).to eq(2000)
      end
    end

    describe "#category_percentage" do
      it "calculates percentage of income" do
        # 2000 / 5000 = 40%
        expect(budget.category_percentage("fixed")).to eq(40.0)
      end
    end

    describe "#total_expenses_usd" do
      it "sums all budget items in USD" do
        # 2000 + 500 + 400 + 500 = 3400
        expect(budget.total_expenses_usd).to eq(3400)
      end
    end
  end
end
