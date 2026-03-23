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

    it "uses the modern mobile-web-app-capable meta tag" do
      get settings_path
      expect(response.body).to include('name="mobile-web-app-capable"')
      expect(response.body).not_to include('name="apple-mobile-web-app-capable"')
    end

    it "loads Google Fonts (Newsreader and Figtree)" do
      get settings_path
      expect(response.body).to include("fonts.googleapis.com")
      expect(response.body).to include("Newsreader")
      expect(response.body).to include("Figtree")
    end

    it "highlights the active nav link for the current page" do
      get settings_path
      expect(response.body).to include('text-blue-600 font-semibold')
    end

    it "renders Cancel button with border style instead of gray fill" do
      get settings_path
      expect(response.body).to include('border border-gray-300 hover:bg-gray-50 text-gray-700')
    end

    it "displays current user settings" do
      get settings_path
      expect(response.body).to include("18") # default vacation days
      expect(response.body).to include("10") # default holiday days
      expect(response.body).to include("8")  # default hours per day
    end

    it "displays default hourly rate field" do
      user.update!(default_hourly_rate: 75.0)
      get settings_path
      expect(response.body).to include("Default hourly rate")
      expect(response.body).to include("75")
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

    it "updates default hourly rate" do
      patch settings_path, params: { user: { default_hourly_rate: 85.0 } }
      expect(response).to redirect_to(settings_path)
      expect(user.reload.default_hourly_rate).to eq(85.0)
    end

    it "shows error for invalid settings" do
      patch settings_path, params: {
        user: { vacation_days_per_year: 100 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "profile updates" do
    describe "PATCH /settings - name update" do
      it "updates the user name" do
        patch settings_path, params: { user: { name: "New Name" } }
        expect(response).to redirect_to(settings_path)
        expect(user.reload.name).to eq("New Name")
      end
    end

    describe "PATCH /settings - email update" do
      it "updates the user email" do
        patch settings_path, params: { user: { email_address: "newemail@example.com" } }
        expect(response).to redirect_to(settings_path)
        expect(user.reload.email_address).to eq("newemail@example.com")
      end

      it "shows error for duplicate email" do
        create(:user, email_address: "taken@example.com")
        patch settings_path, params: { user: { email_address: "taken@example.com" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "PATCH /settings - password change" do
      it "changes password with correct current password" do
        patch settings_path, params: {
          user: {
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          }
        }
        expect(response).to redirect_to(settings_path)
        expect(user.reload.authenticate("newpassword456")).to be_truthy
      end

      it "shows error for incorrect current password" do
        patch settings_path, params: {
          user: {
            current_password: "wrongpassword",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows error for mismatched confirmation" do
        patch settings_path, params: {
          user: {
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "differentpassword"
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "PATCH /settings - combined profile and password update" do
      it "updates name, email, and password simultaneously" do
        patch settings_path, params: {
          user: {
            name: "Updated Name",
            email_address: "updated@example.com",
            current_password: "password123",
            password: "newpassword456",
            password_confirmation: "newpassword456"
          }
        }
        expect(response).to redirect_to(settings_path)
        user.reload
        expect(user.name).to eq("Updated Name")
        expect(user.email_address).to eq("updated@example.com")
        expect(user.authenticate("newpassword456")).to be_truthy
      end
    end
  end

  describe "flash messages" do
    it "renders flash with dismiss controller and close button" do
      patch settings_path, params: { user: { name: "Flash Test" } }
      follow_redirect!
      expect(response.body).to include('data-controller="flash"')
      expect(response.body).to include('data-action="click->flash#dismiss"')
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
