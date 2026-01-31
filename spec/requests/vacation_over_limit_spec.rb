require 'rails_helper'

RSpec.describe "Vacation Over-Limit Flow", type: :request do
  let(:user) { create(:user, vacation_days_per_year: 12, vacation_enabled: true) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "creating entry within limit" do
    it "saves without warning" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 0.5
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
      expect(SalaryEntry.count).to eq(1)
    end
  end

  describe "creating entry over limit" do
    it "rejects without acknowledgment" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 5
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("taking more vacation days than earned")
      expect(SalaryEntry.count).to eq(0)
    end

    it "saves with acknowledgment" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 5,
          vacation_over_limit_acknowledged: "1"
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
      expect(SalaryEntry.count).to eq(1)
      expect(SalaryEntry.last.vacation_days_taken).to eq(5)
    end
  end

  describe "editing entry to go over limit" do
    let!(:entry) { create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5) }

    it "rejects increased days without acknowledgment" do
      patch salary_entry_path(entry), params: {
        salary_entry: { vacation_days_taken: 5 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("taking more vacation days than earned")
    end

    it "saves increased days with acknowledgment" do
      patch salary_entry_path(entry), params: {
        salary_entry: {
          vacation_days_taken: 5,
          vacation_over_limit_acknowledged: "1"
        }
      }

      expect(response).to redirect_to(entry)
      entry.reload
      expect(entry.vacation_days_taken).to eq(5)
    end
  end

  describe "YTD balance across multiple entries" do
    before do
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5)
      create(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 1.0)
      # 2 entries = 2 days earned, 1.5 taken, 0.5 remaining
    end

    it "considers previous entries when calculating limit" do
      # 3rd entry would earn 1 more day (total 3 earned)
      # Taking 2 days would mean 3.5 total taken, only 3 earned = 0.5 over
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 3, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 2
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("taking more vacation days than earned")
    end

    it "allows entry when YTD remains within limit" do
      # Taking 0.5 days = 2 total taken, 3 earned = within limit
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 3, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 0.5
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
    end
  end

  describe "when vacation is disabled" do
    let(:user) { create(:user, vacation_enabled: false) }

    it "allows any amount without warning" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 99
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
    end
  end
end
