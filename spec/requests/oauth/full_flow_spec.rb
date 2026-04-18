require "rails_helper"

RSpec.describe "OAuth full flow", type: :request do
  let(:user) { create(:user) }
  let(:redirect_uri) { "https://expense-tracker.test/cb" }
  let(:state) { "state-abc" }

  before do
    allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([ redirect_uri ])
    sign_in(user)
  end

  it "links salary_calc to an external app end-to-end" do
    get "/oauth/authorize", params: { redirect_uri: redirect_uri, state: state, scopes: "budget:read" }
    expect(response).to have_http_status(:ok)

    post "/oauth/authorize", params: { redirect_uri: redirect_uri, state: state, scopes: "budget:read" }
    expect(response).to have_http_status(:redirect)
    location = URI.parse(response.headers["Location"])
    query = Rack::Utils.parse_nested_query(location.query)
    expect(query["state"]).to eq(state)
    code = query["code"]

    post "/oauth/token",
         params: { grant_type: "authorization_code", code: code, redirect_uri: redirect_uri },
         as: :json
    expect(response).to have_http_status(:ok)
    token = response.parsed_body["access_token"]
    expect(token).to be_present

    MonthlyBudget.create!(user: user, year: Date.current.year, month: Date.current.month, exchange_rate: 503)
    get "/api/v1/monthly_budgets/current", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("monthly_budget", "year")).to eq(Date.current.year)

    api_token = ApiToken.find_by(token_hash: Digest::SHA256.hexdigest(token))
    delete connected_app_path(api_token)
    expect(api_token.reload.active).to be false

    get "/api/v1/monthly_budgets/current", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:unauthorized)
  end
end
