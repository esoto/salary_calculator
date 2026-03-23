# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "rate limiting" do
    it "applies rate limiting to create action" do
      callbacks = RegistrationsController._process_action_callbacks.select do |cb|
        cb.kind == :before && cb.filter.is_a?(Proc)
      end
      rate_limit_callback = callbacks.find do |cb|
        cb.filter.source_location&.first&.include?("rate_limiting")
      end
      expect(rate_limit_callback).to be_present
    end
  end

  describe "GET /registrations/new" do
    it "returns success" do
      get new_registration_path
      expect(response).to have_http_status(:success)
    end

    it "uses the landing layout" do
      get new_registration_path
      expect(response.body).to include("Newsreader")
      expect(response.body).not_to include("bg-gray-100 min-h-screen")
    end

    it "displays the sign-up form" do
      get new_registration_path
      expect(response.body).to include("Create your account")
      expect(response.body).to include("Hourly rate")
    end

    it "includes link to log in" do
      get new_registration_path
      expect(response.body).to include("Already have an account?")
      expect(response.body).to include(new_session_path)
    end
  end

  describe "POST /registrations" do
    let(:valid_params) do
      {
        user: {
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "Test User",
          default_hourly_rate: 50
        }
      }
    end

    it "creates a new user" do
      expect {
        post registrations_path, params: valid_params
      }.to change(User, :count).by(1)
    end

    it "logs in the user and redirects to salary entries" do
      post registrations_path, params: valid_params
      expect(response).to redirect_to(salary_entries_path)
    end

    context "with invalid params" do
      it "does not create user with missing name" do
        expect {
          post registrations_path, params: { user: valid_params[:user].except(:name) }
        }.not_to change(User, :count)
      end

      it "renders new template with unprocessable entity status" do
        post registrations_path, params: { user: valid_params[:user].except(:name) }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "uses the landing layout for validation errors" do
        post registrations_path, params: { user: valid_params[:user].except(:name) }
        expect(response.body).to include("Newsreader")
        expect(response.body).to include("prevented signup")
      end

      it "does not create user with mismatched passwords" do
        expect {
          post registrations_path, params: {
            user: valid_params[:user].merge(password_confirmation: "different")
          }
        }.not_to change(User, :count)
      end

      it "does not create user with invalid email" do
        expect {
          post registrations_path, params: {
            user: valid_params[:user].merge(email_address: "")
          }
        }.not_to change(User, :count)
      end

      it "does not create user with duplicate email" do
        create(:user, email_address: "test@example.com")
        expect {
          post registrations_path, params: valid_params
        }.not_to change(User, :count)
      end
    end
  end
end
