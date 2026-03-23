# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    it "returns success" do
      get new_session_path
      expect(response).to have_http_status(:success)
    end

    it "uses the landing layout" do
      get new_session_path
      expect(response.body).to include("Newsreader")
      expect(response.body).not_to include("bg-gray-100 min-h-screen")
    end

    it "displays the sign-in form" do
      get new_session_path
      expect(response.body).to include("Welcome back")
      expect(response.body).to include("Forgot password?")
      expect(response.body).to include(new_password_path)
    end

    it "includes link to sign up" do
      get new_session_path
      expect(response.body).to include("Create one for free")
      expect(response.body).to include(new_registration_path)
    end

    it "disables Turbo cache to prevent credential restoration" do
      get new_session_path
      expect(response.body).to include('data-turbo-cache="false"')
    end
  end

  describe "POST /session" do
    let(:user) { create(:user) }

    it "redirects with alert on invalid credentials" do
      post session_path, params: { email_address: user.email_address, password: "wrong" }
      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("Try another email address or password.")
    end

    it "redirects to dashboard on valid credentials" do
      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(response).to redirect_to(dashboard_url)
    end

    it "shows welcome flash after successful login" do
      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(flash[:notice]).to include("Welcome")
    end
  end

  describe "DELETE /session" do
    let(:user) { create(:user) }

    before do
      post session_path, params: { email_address: user.email_address, password: "password123" }
    end

    it "shows confirmation flash after logout" do
      delete session_path
      expect(flash[:notice]).to include("logged out")
    end
  end
end
