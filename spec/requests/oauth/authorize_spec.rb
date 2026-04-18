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

  describe "POST /oauth/authorize" do
    before { sign_in(user) }

    it "issues an authorization code and redirects to redirect_uri with code + state" do
      expect {
        post "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      }.to change(OauthAuthorizationCode, :count).by(1)

      expect(response).to have_http_status(:redirect)
      location = URI.parse(response.headers["Location"])
      params_hash = Rack::Utils.parse_nested_query(location.query)
      expect(params_hash["state"]).to eq(state)
      expect(params_hash["code"]).to be_present
    end

    it "rejects an invalid redirect_uri" do
      post "/oauth/authorize", params: { redirect_uri: "https://evil.test/cb", state: state, scopes: "budget:read" }
      expect(response).to have_http_status(:bad_request)
    end

    it "requires authentication" do
      delete_session_cookie_or_sign_out
      post "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      expect(response).to redirect_to(new_session_path)
    end
  end

  private

  def delete_session_cookie_or_sign_out
    cookies[:session_id] = nil
  end
end
