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

      expect(body["expires_in"]).to be_a(Integer)
      expect(body["expires_in"]).to be_within(1.day.to_i).of(10.years.to_i)

      api_token = ApiToken.authenticate(body["access_token"])
      expect(api_token&.user).to eq(user)
      expect(api_token.expires_at).to be_within(1.minute).of(10.years.from_now)
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

    it "rejects a redirect_uri that doesn't match the one bound to the code" do
      other_uri = "https://expense-tracker.test/alternate"
      allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([ redirect_uri, other_uri ])

      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: other_uri, grant_type: "authorization_code" },
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
