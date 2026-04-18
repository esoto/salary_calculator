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
          "exchange_rate" => "503.0",
          "shared_with_household" => false
        )
        expect(body["monthly_budget"]["updated_at"]).to be_present

        expect(body["budget_items"].size).to eq(2)
        first_item = body["budget_items"].first
        expect(first_item).to include(
          "name" => "Rent",
          "category" => "fixed",
          "amount" => "800.0",
          "currency" => "USD",
          "position" => 1,
          "paid" => false
        )
        expect(first_item["updated_at"]).to be_present
      end
    end

    it "returns an empty array when the budget has no items" do
      travel_to Date.new(2026, 4, 17) do
        MonthlyBudget.create!(user: user, year: 2026, month: 4, exchange_rate: 503)
        get "/api/v1/monthly_budgets/current", headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["budget_items"]).to eq([])
      end
    end

    it "orders budget items by position, not creation order" do
      travel_to Date.new(2026, 4, 17) do
        budget = MonthlyBudget.create!(user: user, year: 2026, month: 4, exchange_rate: 503)
        # Create in reverse position order
        budget.budget_items.create!(name: "Second", category: "fixed", amount: 100, currency: "USD", position: 2)
        budget.budget_items.create!(name: "First", category: "fixed", amount: 200, currency: "USD", position: 1)

        get "/api/v1/monthly_budgets/current", headers: headers
        names = response.parsed_body["budget_items"].map { |i| i["name"] }
        expect(names).to eq([ "First", "Second" ])
      end
    end

    it "serializes both USD and CRC currencies correctly" do
      travel_to Date.new(2026, 4, 17) do
        budget = MonthlyBudget.create!(user: user, year: 2026, month: 4, exchange_rate: 503)
        budget.budget_items.create!(name: "Rent", category: "fixed", amount: 800, currency: "USD", position: 1)
        budget.budget_items.create!(name: "Groceries", category: "guilt_free", amount: 50000, currency: "CRC", position: 2)

        get "/api/v1/monthly_budgets/current", headers: headers
        currencies = response.parsed_body["budget_items"].map { |i| i["currency"] }
        expect(currencies).to contain_exactly("USD", "CRC")
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

    it "returns 304 when If-Modified-Since matches budget.updated_at" do
      travel_to Date.new(2026, 4, 17) do
        budget = MonthlyBudget.create!(user: user, year: 2026, month: 4, exchange_rate: 503)
        get "/api/v1/monthly_budgets/current",
          headers: headers.merge("If-Modified-Since" => budget.updated_at.httpdate)
        expect(response).to have_http_status(:not_modified)
      end
    end
  end
end
