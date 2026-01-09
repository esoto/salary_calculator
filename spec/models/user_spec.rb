require 'rails_helper'

RSpec.describe User, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email_address) }
    it { should validate_uniqueness_of(:email_address).case_insensitive }
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:default_hourly_rate).is_greater_than(0).allow_nil }
  end

  describe 'associations' do
    it { should have_many(:salary_entries).dependent(:destroy) }
  end

  describe '#password_reset_token' do
    let(:user) { create(:user) }

    it 'generates a valid token' do
      token = user.password_reset_token
      expect(token).to be_present
      expect(token).to be_a(String)
    end

    it 'can find user by valid token' do
      token = user.password_reset_token
      found_user = User.find_by_password_reset_token!(token)
      expect(found_user).to eq(user)
    end

    it 'token expires after 15 minutes' do
      token = user.password_reset_token

      travel_to 16.minutes.from_now do
        expect {
          User.find_by_password_reset_token!(token)
        }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
      end
    end

    it 'token is invalidated after password change' do
      token = user.password_reset_token

      user.update!(password: 'newpassword123', password_confirmation: 'newpassword123')

      expect {
        User.find_by_password_reset_token!(token)
      }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
    end
  end
end
