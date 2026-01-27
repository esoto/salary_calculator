require 'rails_helper'

RSpec.describe HouseholdMembership, type: :model do
  describe 'associations' do
    it { should belong_to(:household) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { create(:household_membership) }

    it 'validates uniqueness of user_id' do
      should validate_uniqueness_of(:user_id).with_message('is already in a household')
    end
  end

  describe 'joined_at' do
    it 'sets joined_at on create' do
      membership = create(:household_membership)
      expect(membership.joined_at).to be_present
    end
  end
end
