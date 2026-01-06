require 'rails_helper'

RSpec.describe SalaryEntry, type: :model do
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

    it { should validate_uniqueness_of(:month).scoped_to(:year) }
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
end
