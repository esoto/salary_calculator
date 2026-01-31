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
end
