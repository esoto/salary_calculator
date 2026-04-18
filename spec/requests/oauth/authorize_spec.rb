require "rails_helper"

RSpec.describe "OAuth Authorize", type: :request do
  let(:user) { create(:user) }
  let(:valid_redirect) { "https://expense-tracker.test/cb" }
  let(:state) { "client-state-123" }

  before do
    allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([ valid_redirect ])
  end

  describe "GET /oauth/authorize" do
    it "redirects to login when unauthenticated" do
      get "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      expect(response).to redirect_to(new_session_path)
    end

    it "renders the consent page when authenticated with a valid redirect_uri" do
      sign_in(user)
      get "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Expense Tracker")
      expect(response.body).to include("budget:read")
    end

    it "rejects redirect_uri not in the allowlist" do
      sign_in(user)
      get "/oauth/authorize", params: { redirect_uri: "https://evil.test/cb", state: state, scopes: "budget:read" }
      expect(response).to have_http_status(:bad_request)
    end

    it "requires a state parameter" do
      sign_in(user)
      get "/oauth/authorize", params: { redirect_uri: valid_redirect, scopes: "budget:read" }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
