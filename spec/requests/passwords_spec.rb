require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  include ActiveJob::TestHelper

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
        expect(email.to).to eq([user.email_address])
        expect(email.subject).to eq("Reset your password")
      end

      it "redirects with success message" do
        post passwords_path, params: { email_address: user.email_address }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Password reset instructions sent")
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
        expect(response.body).to include("Password reset instructions sent")
      end
    end
  end
end
