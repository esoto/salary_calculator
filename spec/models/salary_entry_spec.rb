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

    describe '#monthly_salary' do
      it 'calculates hours_worked * hourly_rate' do
        expect(entry.monthly_salary).to eq(8000.0)
      end
    end

    describe '#aguinaldo_savings' do
      it 'calculates monthly_salary / 12' do
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

    describe '#total_savings' do
      it 'sums all savings' do
        expected = entry.aguinaldo_savings + entry.vacation_savings + entry.holiday_savings
        expect(entry.total_savings).to be_within(0.01).of(expected)
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
end
