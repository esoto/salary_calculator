require 'rails_helper'

RSpec.describe "SalaryEntries", type: :request do
  describe "GET /salary_entries" do
    it "returns success" do
      get salary_entries_path
      expect(response).to have_http_status(:success)
    end

    it "filters by year" do
      create(:salary_entry, month: 6, year: 2024, hours_worked: 100)
      create(:salary_entry, month: 1, year: 2025, hours_worked: 160)

      get salary_entries_path(year: 2025)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("January")
      expect(response.body).not_to include("June")
    end
  end

  describe "GET /salary_entries/:id" do
    it "returns success" do
      entry = create(:salary_entry)
      get salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /salary_entries/new" do
    it "returns success" do
      get new_salary_entry_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /salary_entries" do
    let(:valid_params) do
      { salary_entry: { month: 1, year: 2025, hours_worked: 160, hourly_rate: 50 } }
    end

    it "creates a new entry" do
      expect {
        post salary_entries_path, params: valid_params
      }.to change(SalaryEntry, :count).by(1)
    end

    it "redirects to show page" do
      post salary_entries_path, params: valid_params
      expect(response).to redirect_to(salary_entry_path(SalaryEntry.last))
    end
  end

  describe "GET /salary_entries/:id/edit" do
    it "returns success" do
      entry = create(:salary_entry)
      get edit_salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /salary_entries/:id" do
    let(:entry) { create(:salary_entry, hours_worked: 160) }

    it "updates the entry" do
      patch salary_entry_path(entry), params: { salary_entry: { hours_worked: 180 } }
      expect(entry.reload.hours_worked).to eq(180)
    end

    it "redirects to show page" do
      patch salary_entry_path(entry), params: { salary_entry: { hours_worked: 180 } }
      expect(response).to redirect_to(salary_entry_path(entry))
    end
  end

  describe "DELETE /salary_entries/:id" do
    it "deletes the entry" do
      entry = create(:salary_entry)
      expect {
        delete salary_entry_path(entry)
      }.to change(SalaryEntry, :count).by(-1)
    end

    it "redirects to index" do
      entry = create(:salary_entry)
      delete salary_entry_path(entry)
      expect(response).to redirect_to(salary_entries_path)
    end
  end

  describe "GET /salary_entries/summary" do
    it "returns success" do
      get summary_salary_entries_path(year: 2025)
      expect(response).to have_http_status(:success)
    end
  end
end
