require 'rails_helper'

RSpec.describe Household, type: :model do
  describe 'validations' do
    subject { build(:household) }

    it { should validate_presence_of(:name) }

    it 'validates uniqueness of invite_code' do
      create(:household)
      should validate_uniqueness_of(:invite_code)
    end

    it 'validates presence of invite_code when not auto-generated' do
      household = Household.new(name: 'Test')
      # Stub the callback to prevent auto-generation
      allow(household).to receive(:generate_invite_code)
      household.invite_code = nil
      expect(household).not_to be_valid
      expect(household.errors[:invite_code]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it { should have_many(:household_memberships).dependent(:destroy) }
    it { should have_many(:members).through(:household_memberships).source(:user) }
  end

  describe 'invite_code generation' do
    it 'generates invite_code on create' do
      household = Household.create!(name: 'Test Family')
      expect(household.invite_code).to be_present
      expect(household.invite_code.length).to eq(6)
    end

    it 'generates uppercase alphanumeric code' do
      household = Household.create!(name: 'Test Family')
      expect(household.invite_code).to match(/\A[A-Z0-9]{6}\z/)
    end
  end

  describe '#regenerate_invite_code!' do
    it 'generates a new invite code' do
      household = create(:household)
      old_code = household.invite_code
      household.regenerate_invite_code!
      expect(household.invite_code).not_to eq(old_code)
    end
  end

  describe '#combined_earnings_for_year' do
    let(:household) { create(:household) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      create(:household_membership, household: household, user: user1)
      create(:household_membership, household: household, user: user2)
      create(:salary_entry, user: user1, year: 2026, month: 1, hours_worked: 100, hourly_rate: 50)
      create(:salary_entry, user: user1, year: 2026, month: 2, hours_worked: 100, hourly_rate: 50)
      create(:salary_entry, user: user2, year: 2026, month: 1, hours_worked: 80, hourly_rate: 50)
    end

    it 'sums earnings from all members for the year' do
      expect(household.combined_earnings_for_year(2026)).to eq(14000)
    end

    it 'returns 0 for year with no entries' do
      expect(household.combined_earnings_for_year(2025)).to eq(0)
    end
  end

  describe '#combined_savings_for_year' do
    let(:household) { create(:household) }
    let(:user1) { create(:user, aguinaldo_enabled: true, vacation_enabled: true, holiday_enabled: true) }
    let(:user2) { create(:user, aguinaldo_enabled: true, vacation_enabled: true, holiday_enabled: true) }

    before do
      create(:household_membership, household: household, user: user1)
      create(:household_membership, household: household, user: user2)
      create(:salary_entry, user: user1, year: 2026, month: 1, hours_worked: 100, hourly_rate: 50)
      create(:salary_entry, user: user2, year: 2026, month: 1, hours_worked: 80, hourly_rate: 50)
    end

    it 'sums savings from all members for the year' do
      total = household.combined_savings_for_year(2026)
      expect(total).to be > 0
    end
  end

  describe '#member_stats_for_year' do
    let(:household) { create(:household) }
    let(:user1) { create(:user, name: 'Alice') }
    let(:user2) { create(:user, name: 'Bob') }

    before do
      create(:household_membership, household: household, user: user1)
      create(:household_membership, household: household, user: user2)
      create(:salary_entry, user: user1, year: 2026, month: 1, hours_worked: 100, hourly_rate: 50)
      create(:salary_entry, user: user2, year: 2026, month: 1, hours_worked: 80, hourly_rate: 50)
    end

    it 'returns stats for each member' do
      stats = household.member_stats_for_year(2026)
      expect(stats.length).to eq(2)
      expect(stats.map { |s| s[:name] }).to contain_exactly('Alice', 'Bob')
    end

    it 'includes earnings and savings per member' do
      stats = household.member_stats_for_year(2026)
      alice_stats = stats.find { |s| s[:name] == 'Alice' }
      expect(alice_stats[:earnings]).to eq(5000)
      expect(alice_stats[:savings]).to be_present
    end
  end
end
