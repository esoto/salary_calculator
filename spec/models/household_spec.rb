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
end
