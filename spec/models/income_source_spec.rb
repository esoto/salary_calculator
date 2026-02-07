require 'rails_helper'

RSpec.describe IncomeSource, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:linked_user).class_name("User").optional }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe "enums" do
    it { should define_enum_for(:currency).with_values(crc: "CRC", usd: "USD").backed_by_column_of_type(:string) }
    it { should define_enum_for(:income_type).with_values(hourly: "hourly", fixed: "fixed").backed_by_column_of_type(:string) }
  end

  describe "enum scopes and predicates" do
    let(:user) { create(:user) }
    let!(:fixed_source) { create(:income_source, user: user, income_type: "fixed") }
    let!(:hourly_source) { create(:income_source, user: user, income_type: "hourly") }

    it "provides income_type scopes" do
      expect(IncomeSource.fixed).to include(fixed_source)
      expect(IncomeSource.hourly).to include(hourly_source)
    end

    it "provides predicates" do
      expect(fixed_source.fixed?).to be true
      expect(hourly_source.hourly?).to be true
    end

    it "provides with_salary_data scope for eager loading" do
      expect(IncomeSource.with_salary_data.to_sql).to include("income_sources")
    end
  end

  describe "#amount_for_month" do
    let(:user) { create(:user) }

    context "with fixed income type" do
      let(:source) { create(:income_source, user: user, income_type: "fixed", amount: 5000, currency: "USD") }

      it "returns the fixed amount" do
        expect(source.amount_for_month(2026, 1)).to eq(5000)
      end
    end

    context "with hourly income type linked to user" do
      let(:linked_user) { create(:user) }
      let(:source) { create(:income_source, user: user, linked_user: linked_user, income_type: "hourly") }
      # Salary entry for January 2026
      let!(:salary_entry) { create(:salary_entry, user: linked_user, year: 2026, month: 1, hours_worked: 160, hourly_rate: 50) }

      it "returns previous month's net pay (Feb looks at Jan)" do
        # February 2026 should use January 2026's salary entry
        expect(source.amount_for_month(2026, 2)).to be_within(0.01).of(6400)
      end

      it "returns 0 when previous month has no salary entry" do
        # January 2026 looks at December 2025, which doesn't exist
        expect(source.amount_for_month(2026, 1)).to eq(0)
      end

      it "handles year boundary (Jan looks at previous Dec)" do
        dec_entry = create(:salary_entry, user: linked_user, year: 2025, month: 12, hours_worked: 140, hourly_rate: 50)
        # January 2026 should use December 2025's salary entry
        expect(source.amount_for_month(2026, 1)).to be_within(0.01).of(dec_entry.net_pay)
      end
    end
  end

  describe "authorization" do
    let(:owner) { create(:user) }
    let(:household_member) { create(:user) }
    let(:stranger) { create(:user) }
    let(:household) { create(:household) }
    let(:income_source) { create(:income_source, user: owner) }

    before do
      create(:household_membership, household: household, user: owner)
      create(:household_membership, household: household, user: household_member)
    end

    describe "#owned_by?" do
      it "returns true for owner" do
        expect(income_source.owned_by?(owner)).to be true
      end

      it "returns false for household member" do
        expect(income_source.owned_by?(household_member)).to be false
      end

      it "returns false for stranger" do
        expect(income_source.owned_by?(stranger)).to be false
      end
    end

    describe "#accessible_by?" do
      context "when owner has no shared budgets" do
        it "returns true for owner" do
          expect(income_source.accessible_by?(owner)).to be true
        end

        it "returns false for household member" do
          expect(income_source.accessible_by?(household_member)).to be false
        end

        it "returns false for stranger" do
          expect(income_source.accessible_by?(stranger)).to be false
        end
      end

      context "when owner has shared budget" do
        before do
          create(:monthly_budget, user: owner, shared_with_household: true)
        end

        it "returns true for owner" do
          expect(income_source.accessible_by?(owner)).to be true
        end

        it "returns true for household member" do
          expect(income_source.accessible_by?(household_member)).to be true
        end

        it "returns false for stranger" do
          expect(income_source.accessible_by?(stranger)).to be false
        end
      end
    end

    describe "#editable_by?" do
      context "without linked_user" do
        before do
          create(:monthly_budget, user: owner, shared_with_household: true)
        end

        it "returns true for owner" do
          expect(income_source.editable_by?(owner)).to be true
        end

        it "returns true for household member when accessible" do
          expect(income_source.editable_by?(household_member)).to be true
        end
      end

      context "with linked_user" do
        let(:linked_income) { create(:income_source, user: owner, linked_user: household_member) }

        before do
          create(:monthly_budget, user: owner, shared_with_household: true)
        end

        it "returns true for owner (owner always has edit control)" do
          expect(linked_income.editable_by?(owner)).to be true
        end

        it "returns true for linked user" do
          expect(linked_income.editable_by?(household_member)).to be true
        end

        it "returns false for stranger" do
          expect(linked_income.editable_by?(stranger)).to be false
        end
      end
    end
  end
end
