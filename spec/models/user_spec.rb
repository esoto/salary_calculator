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

  describe "savings settings validations" do
    subject { build(:user) }

    it { should validate_numericality_of(:vacation_days_per_year).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(50) }
    it { should validate_numericality_of(:holiday_days_per_year).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(30) }
    it { should validate_numericality_of(:hours_per_day).is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12) }
  end

  describe "savings settings defaults" do
    let(:user) { User.create!(name: "Test", email_address: "test@example.com", password: "password123") }

    it "sets default vacation_days_per_year to 18" do
      expect(user.vacation_days_per_year).to eq(18)
    end

    it "sets default holiday_days_per_year to 10" do
      expect(user.holiday_days_per_year).to eq(10)
    end

    it "sets default hours_per_day to 8" do
      expect(user.hours_per_day).to eq(8)
    end

    it "enables aguinaldo by default" do
      expect(user.aguinaldo_enabled).to be true
    end

    it "enables vacation by default" do
      expect(user.vacation_enabled).to be true
    end

    it "enables holiday by default" do
      expect(user.holiday_enabled).to be true
    end
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

      user.instance_variable_set(:@skip_current_password_validation, true)
      user.update!(password: 'newpassword123', password_confirmation: 'newpassword123')

      expect {
        User.find_by_password_reset_token!(token)
      }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
    end
  end

  describe "#vacation_balance_for_year" do
    let(:user) { create(:user, vacation_days_per_year: 12) } # 1 day earned per month

    context "with no entries" do
      it "returns zero balance" do
        balance = user.vacation_balance_for_year(2025)
        expect(balance[:earned]).to eq(0)
        expect(balance[:taken]).to eq(0)
        expect(balance[:balance]).to eq(0)
      end
    end

    context "with entries and no vacation taken" do
      before do
        create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
        create(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 0)
      end

      it "calculates days earned based on entry count" do
        balance = user.vacation_balance_for_year(2025)
        expect(balance[:earned]).to eq(2.0) # 2 months * 1 day/month
        expect(balance[:taken]).to eq(0)
        expect(balance[:balance]).to eq(2.0)
      end
    end

    context "with vacation days taken" do
      before do
        create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5)
        create(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 1)
      end

      it "calculates correct balance" do
        balance = user.vacation_balance_for_year(2025)
        expect(balance[:earned]).to eq(2.0)
        expect(balance[:taken]).to eq(1.5)
        expect(balance[:balance]).to eq(0.5)
      end
    end

    context "with exclude_entry for new record" do
      before do
        create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
      end

      it "includes new entry in calculation" do
        new_entry = user.salary_entries.build(year: 2025, month: 2, vacation_days_taken: 1.5)
        balance = user.vacation_balance_for_year(2025, exclude_entry: new_entry)
        expect(balance[:earned]).to eq(2.0) # existing + new entry
        expect(balance[:taken]).to eq(1.5)  # new entry's days
        expect(balance[:balance]).to eq(0.5)
      end
    end

    context "with exclude_entry for persisted record" do
      let!(:entry) { create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 1) }

      it "excludes persisted value and includes new value" do
        entry.vacation_days_taken = 2.0 # changing from 1 to 2
        balance = user.vacation_balance_for_year(2025, exclude_entry: entry)
        expect(balance[:earned]).to eq(1.0)
        expect(balance[:taken]).to eq(2.0) # new value, not old
        expect(balance[:balance]).to eq(-1.0)
      end
    end

    context "with entries from different years" do
      before do
        create(:salary_entry, user: user, year: 2024, month: 12, vacation_days_taken: 0.5)
        create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 1)
      end

      it "only considers entries from specified year" do
        balance = user.vacation_balance_for_year(2025)
        expect(balance[:earned]).to eq(1.0)
        expect(balance[:taken]).to eq(1.0)
        expect(balance[:balance]).to eq(0.0)
      end
    end
  end

  describe "password change validation" do
    let(:user) { create(:user, password: "oldpassword123") }

    context "when password is being changed" do
      it "is valid with correct current password" do
        user.current_password = "oldpassword123"
        user.password = "newpassword123"
        user.password_confirmation = "newpassword123"
        expect(user).to be_valid
      end

      it "is invalid without current password" do
        user.password = "newpassword123"
        user.password_confirmation = "newpassword123"
        expect(user).not_to be_valid
        expect(user.errors[:current_password]).to include("can't be blank")
      end

      it "is invalid with incorrect current password" do
        user.current_password = "wrongpassword"
        user.password = "newpassword123"
        user.password_confirmation = "newpassword123"
        expect(user).not_to be_valid
        expect(user.errors[:current_password]).to include("is incorrect")
      end

      it "is invalid when password confirmation doesn't match" do
        user.current_password = "oldpassword123"
        user.password = "newpassword123"
        user.password_confirmation = "differentpassword"
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("doesn't match Password")
      end
    end

    context "when password is not being changed" do
      it "skips password validation when password fields are blank" do
        user.name = "New Name"
        expect(user).to be_valid
      end

      it "allows updating other fields without current password" do
        user.email_address = "newemail@example.com"
        expect(user).to be_valid
      end
    end
  end
end
