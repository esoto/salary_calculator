require "rails_helper"

RSpec.describe "OAuth Token", type: :request do
  let(:user) { create(:user) }
  let(:redirect_uri) { "https://expense-tracker.test/cb" }
  let!(:issued) do
    OauthAuthorizationCode.issue(user: user, redirect_uri: redirect_uri, scopes: "budget:read")
  end

  before do
    allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([ redirect_uri ])
  end

  describe "POST /oauth/token" do
    it "exchanges a valid code for an API token" do
      expect {
        post "/oauth/token",
             params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
             as: :json
      }.to change { ApiToken.count }.by(1)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["access_token"]).to be_present
      expect(body["token_type"]).to eq("Bearer")
      expect(body["scope"]).to eq("budget:read")

      expect(ApiToken.authenticate(body["access_token"])&.user).to eq(user)
    end

    it "rejects a reused code" do
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:ok)

      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a mismatched redirect_uri" do
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: "https://other.test/cb", grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects unsupported grant_type" do
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "password" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects redirect_uri not in allowlist" do
      allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([])
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end
end
