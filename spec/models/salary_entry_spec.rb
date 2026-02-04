require 'rails_helper'

RSpec.describe SalaryEntry, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:salary_entry) }

    it { should validate_presence_of(:month) }
    it { should validate_presence_of(:year) }
    it { should validate_presence_of(:hours_worked) }
    it { should validate_presence_of(:hourly_rate) }

    it { should validate_numericality_of(:month).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12) }
    it { should validate_numericality_of(:year).only_integer.is_greater_than_or_equal_to(2020).is_less_than_or_equal_to(2100) }
    it { should validate_numericality_of(:hours_worked).is_greater_than(0) }
    it { should validate_numericality_of(:hourly_rate).is_greater_than(0) }

    it { should validate_uniqueness_of(:month).scoped_to(:year, :user_id) }

    it { should validate_numericality_of(:vacation_days_taken).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:holiday_days_taken).is_greater_than_or_equal_to(0) }
  end

  describe 'calculations' do
    let(:entry) { build(:salary_entry, hours_worked: 160, hourly_rate: 50.0) }

    describe '#base_salary' do
      it 'calculates hours_worked * hourly_rate' do
        expect(entry.base_salary).to eq(8000.0)
      end
    end

    describe '#gross_salary' do
      it 'equals base_salary when no vacation taken' do
        expect(entry.gross_salary).to eq(8000.0)
      end

      it 'includes vacation pay when vacation days taken' do
        entry = build(:salary_entry, hours_worked: 160, hourly_rate: 50, vacation_days_taken: 1)
        # base_salary = 8000, vacation_spent = 400
        expect(entry.gross_salary).to eq(8400.0)
      end
    end

    describe '#bank_fee' do
      it 'returns 0 when bank_fee_enabled is false' do
        entry.user.update!(bank_fee_enabled: false)
        expect(entry.bank_fee).to eq(0)
      end

      it 'returns 40 when bank_fee_enabled is true' do
        entry.user.update!(bank_fee_enabled: true)
        expect(entry.bank_fee).to eq(40)
      end
    end

    describe '#monthly_salary' do
      it 'equals base_salary when no vacation taken and no bank fee' do
        expect(entry.monthly_salary).to eq(8000.0)
      end

      it 'includes vacation pay when vacation days taken' do
        entry = build(:salary_entry, hours_worked: 160, hourly_rate: 50, vacation_days_taken: 1)
        # base_salary = 160 * 50 = 8000
        # vacation_spent = 1 day * 8 hours * $50 = 400
        # monthly_salary = 8000 + 400 = 8400
        expect(entry.monthly_salary).to eq(8400.0)
      end

      it 'deducts bank fee when enabled' do
        entry.user.update!(bank_fee_enabled: true)
        # base_salary = 8000, bank_fee = 40
        # monthly_salary = 8000 - 40 = 7960
        expect(entry.monthly_salary).to eq(7960.0)
      end
    end

    describe '#aguinaldo_savings' do
      it 'calculates gross_salary / 12' do
        expect(entry.aguinaldo_savings).to be_within(0.01).of(666.67)
      end

      it 'includes vacation pay in calculation' do
        entry = build(:salary_entry, hours_worked: 160, hourly_rate: 50, vacation_days_taken: 1)
        # gross_salary = 8000 + 400 = 8400
        # aguinaldo = 8400 / 12 = 700
        expect(entry.aguinaldo_savings).to eq(700.0)
      end

      it 'does not include bank fee deduction' do
        entry.user.update!(bank_fee_enabled: true)
        # gross_salary = 8000 (bank fee doesn't affect aguinaldo)
        # aguinaldo = 8000 / 12 = 666.67
        expect(entry.aguinaldo_savings).to be_within(0.01).of(666.67)
      end
    end

    describe '#vacation_savings' do
      it 'calculates 12 hours * hourly_rate (18 days * 8 hours / 12 months)' do
        expect(entry.vacation_savings).to eq(600.0)
      end
    end

    describe '#holiday_savings' do
      it 'calculates 6.67 hours * hourly_rate (10 days * 8 hours / 12 months)' do
        expect(entry.holiday_savings).to be_within(0.01).of(333.33)
      end
    end

    describe '#monthly_savings_accrual' do
      it 'sums raw savings without balance adjustments' do
        # aguinaldo = 666.67, vacation = 600, holiday = 333.33
        expected = entry.aguinaldo_savings + entry.vacation_savings + entry.holiday_savings
        expect(entry.monthly_savings_accrual).to be_within(0.01).of(expected)
      end

      it 'ignores time off taken (unlike total_savings)' do
        entry = build(:salary_entry, hours_worked: 160, hourly_rate: 50, vacation_days_taken: 1, holiday_days_taken: 0.5)

        # base_salary = 8000
        # vacation_spent = 1 * 8 * 50 = 400, holiday_spent = 0.5 * 8 * 50 = 200
        # gross_salary = 8000 + 400 + 200 = 8600
        # aguinaldo = 8600/12 = 716.67
        # vacation = 600, holiday = 333.33
        # monthly_savings_accrual = 716.67 + 600 + 333.33 = 1650
        expect(entry.monthly_savings_accrual).to be_within(0.01).of(1650)
      end
    end

    describe '#total_savings' do
      it 'sums all savings' do
        expected = entry.aguinaldo_savings + entry.vacation_savings + entry.holiday_savings
        expect(entry.total_savings).to be_within(0.01).of(expected)
      end

      it 'reflects time off taken' do
        entry = build(:salary_entry, hours_worked: 160, hourly_rate: 50, vacation_days_taken: 1, holiday_days_taken: 0.5)

        # base_salary = 8000
        # vacation_spent = 1 * 8 * 50 = 400, holiday_spent = 0.5 * 8 * 50 = 200
        # gross_salary = 8000 + 400 + 200 = 8600
        # aguinaldo = 8600/12 = 716.67
        # vacation_balance = 600 - 400 = 200
        # holiday_balance = 333.33 - 200 = 133.33
        # total = 716.67 + 200 + 133.33 = 1050

        expect(entry.total_savings).to be_within(1).of(1050)
      end
    end

    describe '#vacation_spent' do
      it 'calculates cost of vacation days taken' do
        entry = build(:salary_entry, hourly_rate: 50, vacation_days_taken: 2)
        expect(entry.vacation_spent).to eq(800) # 2 days * 8 hours * $50
      end

      it 'returns 0 when no days taken' do
        entry = build(:salary_entry, hourly_rate: 50, vacation_days_taken: 0)
        expect(entry.vacation_spent).to eq(0)
      end
    end

    describe '#holiday_spent' do
      it 'calculates cost of holiday days taken' do
        entry = build(:salary_entry, hourly_rate: 50, holiday_days_taken: 1.5)
        expect(entry.holiday_spent).to eq(600) # 1.5 days * 8 hours * $50
      end
    end

    describe '#vacation_balance' do
      it 'returns savings minus spent' do
        entry = build(:salary_entry, hourly_rate: 50, vacation_days_taken: 1)
        # vacation_savings = 12 hours * $50 = $600
        # vacation_spent = 1 day * 8 hours * $50 = $400
        expect(entry.vacation_balance).to eq(200)
      end
    end

    describe '#holiday_balance' do
      it 'returns savings minus spent' do
        entry = build(:salary_entry, hourly_rate: 60, holiday_days_taken: 0.5)
        # holiday_savings = 6.67 hours * $60 = $400
        # holiday_spent = 0.5 days * 8 hours * $60 = $240
        expect(entry.holiday_balance).to be_within(1).of(160)
      end
    end
  end

  describe 'scopes' do
    describe '.for_year' do
      let!(:entry_2024) { create(:salary_entry, month: 1, year: 2024) }
      let!(:entry_2025_jan) { create(:salary_entry, month: 1, year: 2025) }
      let!(:entry_2025_feb) { create(:salary_entry, month: 2, year: 2025) }

      it 'returns entries for the given year' do
        expect(SalaryEntry.for_year(2025)).to contain_exactly(entry_2025_jan, entry_2025_feb)
      end
    end

    describe '.ordered' do
      let!(:entry_2025_mar) { create(:salary_entry, month: 3, year: 2025) }
      let!(:entry_2024_dec) { create(:salary_entry, month: 12, year: 2024) }
      let!(:entry_2025_jan) { create(:salary_entry, month: 1, year: 2025) }

      it 'returns entries ordered by year and month' do
        expect(SalaryEntry.ordered).to eq([ entry_2024_dec, entry_2025_jan, entry_2025_mar ])
      end
    end

    describe '.for_aguinaldo_period' do
      let(:user) { create(:user) }

      it 'includes December of previous year' do
        entry = create(:salary_entry, user: user, month: 12, year: 2025)
        expect(user.salary_entries.for_aguinaldo_period(2026)).to include(entry)
      end

      it 'includes January through November of current year' do
        jan = create(:salary_entry, user: user, month: 1, year: 2026)
        nov = create(:salary_entry, user: user, month: 11, year: 2026)
        expect(user.salary_entries.for_aguinaldo_period(2026)).to include(jan, nov)
      end

      it 'excludes December of current year' do
        entry = create(:salary_entry, user: user, month: 12, year: 2026)
        expect(user.salary_entries.for_aguinaldo_period(2026)).not_to include(entry)
      end

      it 'excludes entries from other years' do
        entry = create(:salary_entry, user: user, month: 6, year: 2024)
        expect(user.salary_entries.for_aguinaldo_period(2026)).not_to include(entry)
      end
    end
  end

  describe '.yearly_summary' do
    before do
      create(:salary_entry, month: 1, year: 2025, hours_worked: 160, hourly_rate: 50.0)
      create(:salary_entry, month: 2, year: 2025, hours_worked: 140, hourly_rate: 50.0)
    end

    it 'returns aggregated totals for the year' do
      summary = SalaryEntry.yearly_summary(2025)

      expect(summary[:total_earnings]).to eq(15000.0)
      expect(summary[:total_aguinaldo]).to be_within(0.01).of(1250.0)
      expect(summary[:total_vacation]).to eq(1200.0)
      expect(summary[:total_holidays]).to be_within(0.01).of(666.67)
      expect(summary[:total_savings]).to be_within(0.01).of(3116.67)
      expect(summary[:entries_count]).to eq(2)
    end

    it 'returns zeros for year with no entries' do
      summary = SalaryEntry.yearly_summary(2020)

      expect(summary[:total_earnings]).to eq(0)
      expect(summary[:entries_count]).to eq(0)
    end
  end

  describe "user-specific savings calculations" do
    let(:user) { User.create!(name: "Test", email_address: "calc@example.com", password: "password123") }
    let(:entry) { user.salary_entries.create!(year: 2025, month: 1, hours_worked: 160, hourly_rate: 50) }

    describe "#vacation_savings" do
      it "uses user's vacation_days_per_year setting" do
        user.update!(vacation_days_per_year: 24, hours_per_day: 8)
        # 24 days * 8 hours / 12 months * $50/hr = $800
        expect(entry.vacation_savings).to eq(800.0)
      end

      it "returns 0 when vacation is disabled" do
        user.update!(vacation_enabled: false)
        expect(entry.vacation_savings).to eq(0)
      end
    end

    describe "#holiday_savings" do
      it "uses user's holiday_days_per_year setting" do
        user.update!(holiday_days_per_year: 12, hours_per_day: 8)
        # 12 days * 8 hours / 12 months * $50/hr = $400
        expect(entry.holiday_savings).to eq(400.0)
      end

      it "returns 0 when holiday is disabled" do
        user.update!(holiday_enabled: false)
        expect(entry.holiday_savings).to eq(0)
      end
    end

    describe "#aguinaldo_savings" do
      it "returns 0 when aguinaldo is disabled" do
        user.update!(aguinaldo_enabled: false)
        expect(entry.aguinaldo_savings).to eq(0)
      end

      it "calculates normally when aguinaldo is enabled" do
        user.update!(aguinaldo_enabled: true)
        # 160 hours * $50/hr / 12 = $666.67
        expect(entry.aguinaldo_savings).to be_within(0.01).of(666.67)
      end
    end

    describe "#vacation_spent" do
      it "uses user's hours_per_day setting" do
        user.update!(hours_per_day: 6, vacation_days_per_year: 24)
        entry.update!(vacation_days_taken: 2)
        # 2 days * 6 hours * $50/hr = $600
        expect(entry.vacation_spent).to eq(600.0)
      end
    end

    describe "#holiday_spent" do
      it "uses user's hours_per_day setting" do
        user.update!(hours_per_day: 6)
        entry.update!(holiday_days_taken: 1)
        # 1 day * 6 hours * $50/hr = $300
        expect(entry.holiday_spent).to eq(300.0)
      end
    end
  end

  describe "vacation over-limit validation" do
    let(:user) { create(:user, vacation_days_per_year: 12, vacation_enabled: true) }

    context "when within limit" do
      it "is valid" do
        create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
        entry = build(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 1)
        expect(entry).to be_valid
      end
    end

    context "when over limit and not acknowledged" do
      it "is invalid" do
        entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 5)
        expect(entry).not_to be_valid
        expect(entry.errors[:base]).to include("You're taking more vacation days than earned. Please acknowledge this to continue.")
      end
    end

    context "when over limit and acknowledged" do
      it "is valid" do
        entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 5)
        entry.vacation_over_limit_acknowledged = "1"
        expect(entry).to be_valid
      end
    end

    context "when vacation is disabled" do
      let(:user) { create(:user, vacation_enabled: false) }

      it "skips validation" do
        entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 100)
        expect(entry).to be_valid
      end
    end

    context "when vacation_days_taken is zero" do
      it "skips validation" do
        entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
        expect(entry).to be_valid
      end
    end

    context "when editing existing entry" do
      let!(:entry) { create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5) }

      it "correctly calculates balance excluding old value" do
        entry.vacation_days_taken = 1.0 # still within limit (1 day earned)
        expect(entry).to be_valid
      end

      it "requires acknowledgment when new value exceeds limit" do
        entry.vacation_days_taken = 5.0 # over limit
        expect(entry).not_to be_valid
        entry.vacation_over_limit_acknowledged = "1"
        expect(entry).to be_valid
      end
    end
  end
end
