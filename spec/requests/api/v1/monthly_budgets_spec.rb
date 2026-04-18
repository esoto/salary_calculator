require "rails_helper"

RSpec.describe "Api::V1::MonthlyBudgets", type: :request do
  let(:user) { create(:user) }
  let(:api_token) { ApiToken.create!(user: user, name: "test", scopes: "budget:read") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.token}" } }

  describe "GET /api/v1/monthly_budgets/current" do
    it "returns 404 when no budget exists for the current month" do
      travel_to Date.new(2026, 4, 17) do
        get "/api/v1/monthly_budgets/current", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns the current month's budget with items" do
      travel_to Date.new(2026, 4, 17) do
        budget = MonthlyBudget.create!(user: user, year: 2026, month: 4, exchange_rate: 503)
        budget.budget_items.create!(name: "Rent", category: "fixed", amount: 800, currency: "USD", position: 1)
        budget.budget_items.create!(name: "Groceries", category: "guilt_free", amount: 300, currency: "USD", position: 2)

        get "/api/v1/monthly_budgets/current", headers: headers
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["monthly_budget"]).to include(
          "id" => budget.id,
          "year" => 2026,
          "month" => 4,
          "exchange_rate" => "503.0"
        )
        expect(body["budget_items"].size).to eq(2)
        expect(body["budget_items"].first).to include(
          "name" => "Rent",
          "category" => "fixed",
          "amount" => "800.0",
          "currency" => "USD"
        )
      end
    end

    it "only returns the authenticated user's budget" do
      travel_to Date.new(2026, 4, 17) do
        other_user = create(:user)
        MonthlyBudget.create!(user: other_user, year: 2026, month: 4, exchange_rate: 503)

        get "/api/v1/monthly_budgets/current", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns 401 without a token" do
      travel_to Date.new(2026, 4, 17) do
        get "/api/v1/monthly_budgets/current"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "returns 403 when the token lacks the budget:read scope" do
      no_scope = ApiToken.create!(user: user, name: "limited", scopes: "")
      travel_to Date.new(2026, 4, 17) do
        get "/api/v1/monthly_budgets/current",
          headers: { "Authorization" => "Bearer #{no_scope.token}" }
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body["required"]).to eq("budget:read")
      end
    end
  end
end
