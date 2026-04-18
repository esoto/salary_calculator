require 'rails_helper'

RSpec.describe IncomeSource, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:linked_user).class_name("User").optional }
    it { is_expected.to have_many(:income_source_overrides).dependent(:destroy) }
  end

  describe ".with_override_data" do
    it "eager-loads income_source_overrides to avoid N+1" do
      3.times { create(:income_source_override, income_source: create(:income_source)) }

      queries = []
      callback = ->(_, _, _, _, payload) { queries << payload[:sql] if payload[:sql] =~ /\bincome_source_overrides\b/i }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        IncomeSource.with_override_data.each { |s| s.income_source_overrides.to_a }
      end

      # With 3 sources and eager loading: one "includes" query for overrides.
      # Without eager loading: 3 (one per source). Assert exactly 1.
      expect(queries.size).to eq(1)
    end
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

  describe "#amount_for_month with overrides" do
    let(:source) { create(:income_source, income_type: "fixed", amount: 1000) }

    it "returns base amount when no overrides" do
      expect(source.amount_for_month(2026, 4)).to eq(1000)
    end

    it "single_month override wins for the exact month" do
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 1500, scope: "single_month")
      expect(source.amount_for_month(2026, 4)).to eq(1500)
      expect(source.amount_for_month(2026, 5)).to eq(1000)
    end

    it "from_this_month override applies to target and future months" do
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 1200, scope: "from_this_month")
      expect(source.amount_for_month(2026, 3)).to eq(1000)
      expect(source.amount_for_month(2026, 4)).to eq(1200)
      expect(source.amount_for_month(2026, 12)).to eq(1200)
      expect(source.amount_for_month(2027, 1)).to eq(1200)
    end

    it "later from_this_month supersedes earlier" do
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 1200, scope: "from_this_month")
      create(:income_source_override, income_source: source, year: 2026, month: 7, amount: 1500, scope: "from_this_month")
      expect(source.amount_for_month(2026, 6)).to eq(1200)
      expect(source.amount_for_month(2026, 7)).to eq(1500)
    end

    it "single_month beats from_this_month for the same exact month" do
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 1200, scope: "from_this_month")
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 2000, scope: "single_month")
      expect(source.amount_for_month(2026, 4)).to eq(2000)
      expect(source.amount_for_month(2026, 5)).to eq(1200)
    end

    it "returns 0 when fixed with nil amount and no overrides" do
      nil_source = create(:income_source, income_type: "fixed", amount: nil)
      expect(nil_source.amount_for_month(2026, 4)).to eq(0)
    end

    it "honors single_month override with amount: 0 (zero-out)" do
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 0, scope: "single_month")
      expect(source.amount_for_month(2026, 4)).to eq(0)
      expect(source.amount_for_month(2026, 5)).to eq(1000)
    end

    it "honors from_this_month override with amount: 0 (zero-out going forward)" do
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 0, scope: "from_this_month")
      expect(source.amount_for_month(2026, 3)).to eq(1000)
      expect(source.amount_for_month(2026, 4)).to eq(0)
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
      context "when source is fixed (no linked_user) and owner has a shared budget" do
        let(:fixed_source) { create(:income_source, user: owner, income_type: "fixed") }

        before do
          create(:monthly_budget, user: owner, shared_with_household: true)
        end

        it "owner can edit" do
          expect(fixed_source.editable_by?(owner)).to be true
        end

        it "household member cannot edit (pre-existing bug fix)" do
          expect(fixed_source.editable_by?(household_member)).to be false
        end

        it "household member can still access (read) the source" do
          expect(fixed_source.accessible_by?(household_member)).to be true
        end

        it "returns false for stranger" do
          expect(fixed_source.editable_by?(stranger)).to be false
        end
      end

      context "when source is hourly with a linked_user" do
        let(:linked_income) do
          create(:income_source, user: owner, income_type: "hourly",
                 linked_user: household_member, amount: nil)
        end

        before do
          create(:monthly_budget, user: owner, shared_with_household: true)
        end

        it "owner can edit (owner always has edit control)" do
          expect(linked_income.editable_by?(owner)).to be true
        end

        it "linked user can edit" do
          expect(linked_income.editable_by?(household_member)).to be true
        end

        it "unrelated household member cannot edit" do
          other = create(:user)
          create(:household_membership, user: other, household: household)
          expect(linked_income.editable_by?(other)).to be false
        end

        it "returns false for stranger" do
          expect(linked_income.editable_by?(stranger)).to be false
        end
      end
    end
  end
end
