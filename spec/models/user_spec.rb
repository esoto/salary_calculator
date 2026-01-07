require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email_address) }
    it { should validate_uniqueness_of(:email_address).case_insensitive }
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:default_hourly_rate).is_greater_than(0).allow_nil }
  end

  describe 'associations' do
    # NOTE: Foreign key migration for user_id on salary_entries happens in Task 3
    it { pending 'waiting for user_id foreign key in Task 3'; should have_many(:salary_entries).dependent(:destroy) }
  end
end
