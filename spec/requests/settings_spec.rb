# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user, name: "Settings User") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /settings" do
    it "renders the settings page" do
      get settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Settings")
    end

    it "displays current user settings" do
      get settings_path
      expect(response.body).to include("18") # default vacation days
      expect(response.body).to include("10") # default holiday days
      expect(response.body).to include("8")  # default hours per day
    end
  end

  describe "PATCH /settings" do
    it "updates user settings" do
      patch settings_path, params: {
        user: {
          vacation_days_per_year: 24,
          holiday_days_per_year: 15,
          hours_per_day: 7,
          aguinaldo_enabled: false,
          vacation_enabled: true,
          holiday_enabled: true
        }
      }

      expect(response).to redirect_to(settings_path)
      user.reload
      expect(user.vacation_days_per_year).to eq(24)
      expect(user.holiday_days_per_year).to eq(15)
      expect(user.hours_per_day).to eq(7)
      expect(user.aguinaldo_enabled).to be false
    end

    it "shows error for invalid settings" do
      patch settings_path, params: {
        user: { vacation_days_per_year: 100 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      delete session_path
      get settings_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
