# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, email_address: 'user@example.com', password: 'password123', password_confirmation: 'password123') }

  describe "GET /passwords/new" do
    it "displays password reset request form" do
      get new_password_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Forgot your password?")
    end
  end

  describe "POST /passwords" do
    before do
      ActionMailer::Base.deliveries.clear
    end

    context "with valid email" do
      it "sends password reset email" do
        perform_enqueued_jobs do
          post passwords_path, params: { email_address: user.email_address }
        end

        expect(ActionMailer::Base.deliveries.count).to eq(1)
        email = ActionMailer::Base.deliveries.last
        expect(email.to).to eq([ user.email_address ])
        expect(email.subject).to eq("Reset your password")
      end

      it "redirects with success message" do
        post passwords_path, params: { email_address: user.email_address }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Password reset instructions sent (if user with that email address exists).")
      end
    end

    context "with invalid email" do
      it "does not send email" do
        post passwords_path, params: { email_address: 'nonexistent@example.com' }

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it "still shows success message (security)" do
        post passwords_path, params: { email_address: 'nonexistent@example.com' }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Password reset instructions sent (if user with that email address exists).")
      end
    end
  end

  describe "GET /passwords/:token/edit" do
    context "with valid token" do
      let(:token) { user.password_reset_token }

      it "displays password update form" do
        get edit_password_path(token)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Update your password")
      end
    end

    context "with expired token" do
      let(:token) { user.password_reset_token }

      it "redirects with error message" do
        token # Force token generation before time travel
        travel_to 16.minutes.from_now do
          get edit_password_path(token)

          expect(response).to redirect_to(new_password_path)
          follow_redirect!
          expect(response.body).to include("invalid or has expired")
        end
      end
    end

    context "with invalid token" do
      it "redirects with error message" do
        get edit_password_path('invalid-token')

        expect(response).to redirect_to(new_password_path)
        follow_redirect!
        expect(response.body).to include("invalid or has expired")
      end
    end
  end

  describe "PUT /passwords/:token" do
    let(:token) { user.password_reset_token }

    context "with matching passwords" do
      let(:new_password) { 'newpassword456' }

      it "updates the password" do
        put password_path(token), params: {
          password: new_password,
          password_confirmation: new_password
        }

        user.reload
        expect(user.authenticate(new_password)).to eq(user)
      end

      it "redirects to login with success message" do
        put password_path(token), params: {
          password: new_password,
          password_confirmation: new_password
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Password has been reset")
      end
    end

    context "with mismatched passwords" do
      it "does not update password" do
        original_digest = user.password_digest

        put password_path(token), params: {
          password: 'newpassword456',
          password_confirmation: 'different123'
        }

        user.reload
        expect(user.password_digest).to eq(original_digest)
      end

      it "redirects back with error" do
        put password_path(token), params: {
          password: 'newpassword456',
          password_confirmation: 'different123'
        }

        expect(response).to redirect_to(edit_password_path(token))
        follow_redirect!
        expect(response.body).to include("did not match")
      end
    end

    context "with used token" do
      it "cannot reuse token after password change" do
        # First use - should succeed
        put password_path(token), params: {
          password: 'newpassword456',
          password_confirmation: 'newpassword456'
        }

        # Try to use same token again - should fail
        get edit_password_path(token)
        expect(response).to redirect_to(new_password_path)
        follow_redirect!
        expect(response.body).to include("invalid or has expired")
      end
    end
  end
end
