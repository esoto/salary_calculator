# spec/requests/dashboard_spec.rb
require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, name: "Test User") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /dashboard" do
    it "returns success" do
      get dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "displays user name" do
      get dashboard_path
      expect(response.body).to include("Test User")
    end
  end

  describe "GET / (root)" do
    it "shows dashboard" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
    end
  end

  context "when not logged in" do
    before { delete session_path }

    it "redirects to login" do
      get dashboard_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "with salary entries" do
    before do
      create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50)
      create(:salary_entry, user: user, month: 2, year: 2026, hours_worked: 140, hourly_rate: 50)
    end

    it "displays total earnings" do
      get dashboard_path
      expect(response.body).to include("15,000") # 160*50 + 140*50
    end

    it "displays months logged" do
      get dashboard_path
      expect(response.body).to include("2 of 12")
    end
  end

  context "data isolation" do
    it "does not show other user entries" do
      other_user = create(:user)
      create(:salary_entry, user: other_user, month: 1, year: 2026, hours_worked: 200, hourly_rate: 100)
      create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50)

      get dashboard_path
      expect(response.body).to include("8,000") # user's entry
      expect(response.body).not_to include("20,000") # other user's entry
    end
  end
end
