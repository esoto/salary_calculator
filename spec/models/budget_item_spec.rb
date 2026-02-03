require 'rails_helper'

RSpec.describe BudgetItem, type: :model do
  describe "associations" do
    it { should belong_to(:monthly_budget) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
  end

  describe "enums" do
    it { should define_enum_for(:category).with_values(fixed: "fixed", guilt_free: "guilt_free", savings: "savings", investments: "investments").backed_by_column_of_type(:string) }
    it { should define_enum_for(:currency).with_values(crc: "CRC", usd: "USD").backed_by_column_of_type(:string) }
  end

  describe "enum scopes" do
    let(:budget) { create(:monthly_budget) }
    let!(:fixed_item) { create(:budget_item, monthly_budget: budget, category: "fixed") }
    let!(:savings_item) { create(:budget_item, monthly_budget: budget, category: "savings") }

    it "provides category scopes" do
      expect(BudgetItem.fixed).to include(fixed_item)
      expect(BudgetItem.fixed).not_to include(savings_item)
      expect(BudgetItem.savings).to include(savings_item)
    end
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

  describe "versioning" do
    it "tracks changes with PaperTrail" do
      item = create(:budget_item)
      expect(item).to respond_to(:versions)
    end
  end
end
