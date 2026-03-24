# spec/requests/salary_entries_spec.rb
require 'rails_helper'

RSpec.describe "SalaryEntries", type: :request do
  let(:user) { create(:user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /salary_entries" do
    it "returns success" do
      get salary_entries_path
      expect(response).to have_http_status(:success)
    end

    it "filters by year" do
      create(:salary_entry, user: user, month: 6, year: 2024, hours_worked: 100)
      create(:salary_entry, user: user, month: 1, year: 2025, hours_worked: 160)

      get salary_entries_path(year: 2025)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("January")
      expect(response.body).not_to include("June")
    end

    it "only shows current user entries" do
      other_user = create(:user)
      create(:salary_entry, user: other_user, month: 3, year: 2025)
      create(:salary_entry, user: user, month: 1, year: 2025)

      get salary_entries_path(year: 2025)

      expect(response.body).to include("January")
      expect(response.body).not_to include("March")
    end
  end

  describe "GET /salary_entries/:id" do
    it "returns success for own entry" do
      entry = create(:salary_entry, user: user)
      get salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end

    it "returns not found for other user entry" do
      other_user = create(:user)
      entry = create(:salary_entry, user: other_user)
      get salary_entry_path(entry)
      expect(response).to have_http_status(:not_found)
    end

    it "shows an inviting empty state with guidance" do
      get salary_entries_path(year: 2099)
      expect(response.body).to include("Get started")
      expect(response.body).to include("Track your first month")
    end

    it "displays user's configured vacation and holiday days in savings labels" do
      user.update!(vacation_days_per_year: 20, holiday_days_per_year: 12, vacation_enabled: true, holiday_enabled: true)
      entry = create(:salary_entry, user: user)
      get salary_entry_path(entry)
      expect(response.body).to include("Vacation (20 days)")
      expect(response.body).to include("Holidays (12 days)")
      expect(response.body).not_to include("Vacation (18 days)")
      expect(response.body).not_to include("Holidays (10 days)")
    end

    it "hides disabled savings types in savings breakdown" do
      user.update!(aguinaldo_enabled: false, vacation_enabled: false, holiday_enabled: true)
      entry = create(:salary_entry, user: user)
      get salary_entry_path(entry)
      expect(response.body).not_to include("Aguinaldo")
      expect(response.body).not_to include("Vacation")
      expect(response.body).to include("Holidays")
    end
  end

  describe "GET /salary_entries/new" do
    it "returns success" do
      get new_salary_entry_path
      expect(response).to have_http_status(:success)
    end

    it "pre-fills hourly rate from user default" do
      user.update!(default_hourly_rate: 75.0)
      get new_salary_entry_path
      expect(response.body).to include("75.0")
    end
  end

  describe "POST /salary_entries" do
    let(:valid_params) do
      { salary_entry: { month: 1, year: 2025, hours_worked: 160, hourly_rate: 50 } }
    end

    it "creates a new entry for current user" do
      expect {
        post salary_entries_path, params: valid_params
      }.to change(user.salary_entries, :count).by(1)
    end

    it "redirects to show page" do
      post salary_entries_path, params: valid_params
      expect(response).to redirect_to(salary_entry_path(SalaryEntry.last))
    end
  end

  describe "POST /salary_entries with time off" do
    let(:params_with_time_off) do
      { salary_entry: { month: 3, year: 2026, hours_worked: 160, hourly_rate: 50,
                        vacation_days_taken: 1, holiday_days_taken: 1 } }
    end

    it "saves time off fields" do
      post salary_entries_path, params: params_with_time_off
      entry = SalaryEntry.last
      expect(entry.vacation_days_taken).to eq(1)
      expect(entry.holiday_days_taken).to eq(1)
    end
  end

  describe "GET /salary_entries/:id/edit" do
    it "returns success for own entry" do
      entry = create(:salary_entry, user: user)
      get edit_salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end

    it "returns not found for other user entry" do
      other_user = create(:user)
      entry = create(:salary_entry, user: other_user)
      get edit_salary_entry_path(entry)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /salary_entries/:id" do
    let(:entry) { create(:salary_entry, user: user, hours_worked: 160) }

    it "updates the entry" do
      patch salary_entry_path(entry), params: { salary_entry: { hours_worked: 180 } }
      expect(entry.reload.hours_worked).to eq(180)
    end

    it "redirects to show page" do
      patch salary_entry_path(entry), params: { salary_entry: { hours_worked: 180 } }
      expect(response).to redirect_to(salary_entry_path(entry))
    end

    it "cannot update other user entry" do
      other_user = create(:user)
      entry = create(:salary_entry, user: other_user, hours_worked: 160)
      patch salary_entry_path(entry), params: { salary_entry: { hours_worked: 180 } }
      expect(response).to have_http_status(:not_found)
      expect(entry.reload.hours_worked).to eq(160)
    end
  end

  describe "DELETE /salary_entries/:id" do
    it "deletes the entry" do
      entry = create(:salary_entry, user: user)
      expect {
        delete salary_entry_path(entry)
      }.to change(SalaryEntry, :count).by(-1)
    end

    it "redirects to index" do
      entry = create(:salary_entry, user: user)
      delete salary_entry_path(entry)
      expect(response).to redirect_to(salary_entries_path)
    end

    it "cannot delete other user entry" do
      other_user = create(:user)
      entry = create(:salary_entry, user: other_user)
      delete salary_entry_path(entry)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /salary_entries/summary" do
    it "returns success" do
      get summary_salary_entries_path(year: 2025)
      expect(response).to have_http_status(:success)
    end

    it "displays user's configured vacation and holiday days in savings labels" do
      user.update!(vacation_days_per_year: 25, holiday_days_per_year: 15, vacation_enabled: true, holiday_enabled: true)
      create(:salary_entry, user: user)
      get summary_salary_entries_path(year: Date.current.year)
      expect(response.body).to include("Vacation (25 days)")
      expect(response.body).to include("Holidays (15 days)")
      expect(response.body).not_to include("Vacation (18 days)")
      expect(response.body).not_to include("Holidays (10 days)")
    end
  end

  context "when not logged in" do
    before { delete session_path }

    it "redirects to login" do
      get salary_entries_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "vacation over-limit handling" do
    let(:user) { create(:user, vacation_days_per_year: 12, vacation_enabled: true) }

    before do
      delete session_path
      post session_path, params: { email_address: user.email_address, password: "password123" }
    end

    describe "GET /salary_entries/new" do
      it "calculates over_vacation_limit for new entry" do
        create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 1)
        get new_salary_entry_path, params: { year: 2025, month: 2 }
        expect(response).to be_successful
      end
    end

    describe "POST /salary_entries" do
      context "when over limit without acknowledgment" do
        it "re-renders form with warning" do
          post salary_entries_path, params: {
            salary_entry: {
              year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
              vacation_days_taken: 5
            }
          }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "when over limit with acknowledgment" do
        it "creates entry successfully" do
          post salary_entries_path, params: {
            salary_entry: {
              year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
              vacation_days_taken: 5, vacation_over_limit_acknowledged: "1"
            }
          }
          expect(response).to redirect_to(SalaryEntry.last)
        end
      end
    end
  end
end
