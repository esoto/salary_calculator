# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SharedBudgets", type: :request do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  describe "GET /shared/budgets/:token" do
    context "with valid active share" do
      let!(:share) { create(:budget_share, monthly_budget: budget) }

      it "renders the shared budget view" do
        get shared_budget_path(share.token)
        expect(response).to have_http_status(:ok)
      end

      it "does not require authentication" do
        get shared_budget_path(share.token)
        expect(response).not_to redirect_to(new_session_path)
      end
    end

    context "with expired share" do
      let!(:share) { create(:budget_share, monthly_budget: budget, expires_at: 1.day.ago) }

      it "renders expired view" do
        get shared_budget_path(share.token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("expired")
      end
    end

    context "with invalid token" do
      it "returns 404" do
        get shared_budget_path("invalid-token")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
