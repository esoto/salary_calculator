require "rails_helper"

RSpec.describe "Api::BaseController auth", type: :request do
  # We'll exercise the base class via the monthly_budgets endpoint in Task 6.
  # This spec locks in the behavior of authenticate_token! directly by mounting a tiny test controller.

  controller_class = Class.new(Api::BaseController) do
    def show
      render json: { user_id: Current.user.id }
    end
  end

  before do
    stub_const("Api::AuthTestController", controller_class)
    Rails.application.routes.draw do
      namespace :api do
        get "auth_test", to: "auth_test#show"
      end
    end
  end

  around do |example|
    example.run
  ensure
    Rails.application.reload_routes!
  end

  let(:user) { create(:user) }
  let(:api_token) { ApiToken.create!(user: user, name: "test", scopes: "budget:read") }
  let(:plaintext) { api_token.token }

  it "returns 401 when no Authorization header is provided" do
    get "/api/auth_test"
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq({ "error" => "unauthorized" })
  end

  it "returns 401 when the bearer token is invalid" do
    get "/api/auth_test", headers: { "Authorization" => "Bearer bogus" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "sets Current.user and responds 200 for a valid bearer token" do
    get "/api/auth_test", headers: { "Authorization" => "Bearer #{plaintext}" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq({ "user_id" => user.id })
  end

  it "returns 401 for an expired token" do
    api_token.update!(expires_at: 1.minute.ago)
    get "/api/auth_test", headers: { "Authorization" => "Bearer #{plaintext}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 for an inactive token" do
    api_token.update!(active: false)
    get "/api/auth_test", headers: { "Authorization" => "Bearer #{plaintext}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 when the Authorization scheme is not Bearer" do
    get "/api/auth_test", headers: { "Authorization" => "Basic #{plaintext}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 when the Authorization header lacks a scheme prefix" do
    get "/api/auth_test", headers: { "Authorization" => plaintext }
    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts lowercase bearer scheme per RFC 6750" do
    get "/api/auth_test", headers: { "Authorization" => "bearer #{plaintext}" }
    expect(response).to have_http_status(:ok)
  end
end
