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
end
