require 'rails_helper'

RSpec.describe MonthlyBudget, type: :model do
  include ActiveSupport::Testing::TimeHelpers

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

    describe "#category_status" do
      # Using fixed category: target is { min: 50, max: 60 }
      # With $1000 income, each $10 spent = 1%

      let(:status_user) { create(:user) }
      let!(:status_income) { create(:income_source, user: status_user, amount: 1000, currency: "USD") }
      let(:status_budget) { create(:monthly_budget, user: status_user, exchange_rate: 500) }

      context "when percentage is within target range" do
        before do
          create(:budget_item, monthly_budget: status_budget, category: "fixed", amount: 550, currency: "USD")
        end

        it "returns :ok" do
          expect(status_budget.category_status("fixed")).to eq(:ok)
        end
      end

      context "when percentage is at exact minimum boundary" do
        before do
          create(:budget_item, monthly_budget: status_budget, category: "fixed", amount: 500, currency: "USD")
        end

        it "returns :ok" do
          expect(status_budget.category_status("fixed")).to eq(:ok)
        end
      end

      context "when percentage is at exact maximum boundary" do
        before do
          create(:budget_item, monthly_budget: status_budget, category: "fixed", amount: 600, currency: "USD")
        end

        it "returns :ok" do
          expect(status_budget.category_status("fixed")).to eq(:ok)
        end
      end

      context "when percentage is below min but within warning band (min - 5)" do
        before do
          # 46% is below 50 but >= 45
          create(:budget_item, monthly_budget: status_budget, category: "fixed", amount: 460, currency: "USD")
        end

        it "returns :warning" do
          expect(status_budget.category_status("fixed")).to eq(:warning)
        end
      end

      context "when percentage is more than 5% below min" do
        before do
          # 44% is below 45 (min - 5)
          create(:budget_item, monthly_budget: status_budget, category: "fixed", amount: 440, currency: "USD")
        end

        it "returns :low" do
          expect(status_budget.category_status("fixed")).to eq(:low)
        end
      end

      context "when percentage is above max but within warning band (max + 5)" do
        before do
          # 64% is above 60 but <= 65
          create(:budget_item, monthly_budget: status_budget, category: "fixed", amount: 640, currency: "USD")
        end

        it "returns :warning" do
          expect(status_budget.category_status("fixed")).to eq(:warning)
        end
      end

      context "when percentage is more than 5% above max" do
        before do
          # 66% is above 65 (max + 5)
          create(:budget_item, monthly_budget: status_budget, category: "fixed", amount: 660, currency: "USD")
        end

        it "returns :high" do
          expect(status_budget.category_status("fixed")).to eq(:high)
        end
      end

      context "when category has no defined target" do
        it "returns :ok" do
          expect(status_budget.category_status("unknown")).to eq(:ok)
        end
      end
    end

    describe "#copy_items_from" do
      let(:copy_user) { create(:user) }
      let(:source_budget) { create(:monthly_budget, user: copy_user, year: 2026, month: 1) }
      let(:target_budget) { create(:monthly_budget, user: copy_user, year: 2026, month: 2) }

      before do
        create(:budget_item, monthly_budget: source_budget, name: "Rent", category: "fixed", amount: 1000, currency: "USD", position: 1)
        create(:budget_item, monthly_budget: source_budget, name: "Netflix", category: "guilt_free", amount: 15, currency: "USD", position: 2)
      end

      it "copies all items from source budget" do
        expect {
          target_budget.copy_items_from(source_budget)
        }.to change(target_budget.budget_items, :count).by(2)
      end

      it "copies item attributes" do
        target_budget.copy_items_from(source_budget)
        copied_item = target_budget.budget_items.find_by(name: "Rent")

        expect(copied_item.category).to eq("fixed")
        expect(copied_item.amount).to eq(1000)
        expect(copied_item.currency).to eq("usd")
        expect(copied_item.position).to eq(1)
      end

      it "does not copy paid status" do
        source_budget.budget_items.first.update!(paid: true)
        target_budget.copy_items_from(source_budget)

        expect(target_budget.budget_items.first.paid).to be false
      end
    end
  end

  describe "versioning" do
    it "tracks changes with PaperTrail" do
      budget = create(:monthly_budget)
      expect(budget).to respond_to(:versions)
    end

    it "records who made changes" do
      user = create(:user)
      PaperTrail.request.whodunnit = user.id
      budget = create(:monthly_budget, exchange_rate: 500)
      budget.update!(exchange_rate: 510)

      expect(budget.versions.last.whodunnit).to eq(user.id.to_s)
    end
  end

  describe "#recent_activity" do
    let(:user) { create(:user) }
    let(:budget) { create(:monthly_budget, user: user) }

    it "includes budget versions" do
      budget.update!(exchange_rate: 510)
      activity = budget.recent_activity

      expect(activity).not_to be_empty
      expect(activity.first.item_type).to eq("MonthlyBudget")
    end

    it "includes budget item versions" do
      item = create(:budget_item, monthly_budget: budget)
      item.update!(amount: 100)
      activity = budget.recent_activity

      item_versions = activity.select { |v| v.item_type == "BudgetItem" }
      expect(item_versions).not_to be_empty
    end

    it "orders by most recent first" do
      travel_to 2.seconds.ago do
        budget.update!(exchange_rate: 510)
      end
      budget.update!(exchange_rate: 520)
      activity = budget.recent_activity

      expect(activity.first.created_at).to be >= activity.last.created_at
    end

    it "respects limit parameter" do
      5.times { |i| budget.update!(exchange_rate: 500 + i) }
      activity = budget.recent_activity(limit: 3)

      expect(activity.size).to eq(3)
    end
  end

  describe "ownership and access" do
    let(:owner) { create(:user) }
    let(:partner) { create(:user) }
    let(:stranger) { create(:user) }
    let(:household) { create(:household) }
    let(:budget) { create(:monthly_budget, user: owner) }

    before do
      create(:household_membership, household: household, user: owner)
      create(:household_membership, household: household, user: partner)
    end

    describe "#owned_by?" do
      it "returns true for the owner" do
        expect(budget.owned_by?(owner)).to be true
      end

      it "returns false for non-owners" do
        expect(budget.owned_by?(partner)).to be false
        expect(budget.owned_by?(stranger)).to be false
      end
    end

    describe "#accessible_by?" do
      context "when not shared" do
        it "returns true for owner" do
          expect(budget.accessible_by?(owner)).to be true
        end

        it "returns false for household members" do
          expect(budget.accessible_by?(partner)).to be false
        end

        it "returns false for strangers" do
          expect(budget.accessible_by?(stranger)).to be false
        end
      end

      context "when shared with household" do
        before { budget.update!(shared_with_household: true) }

        it "returns true for owner" do
          expect(budget.accessible_by?(owner)).to be true
        end

        it "returns true for household members" do
          expect(budget.accessible_by?(partner)).to be true
        end

        it "returns false for strangers" do
          expect(budget.accessible_by?(stranger)).to be false
        end
      end
    end

    describe "#editable_by?" do
      it "follows same rules as accessible_by?" do
        expect(budget.editable_by?(owner)).to be true
        expect(budget.editable_by?(partner)).to be false

        budget.update!(shared_with_household: true)
        expect(budget.editable_by?(partner)).to be true
      end
    end
  end
end
