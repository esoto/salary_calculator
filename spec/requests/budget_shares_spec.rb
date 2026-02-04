# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BudgetShares", type: :request do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  before { sign_in(user) }

  describe "POST /budgets/:budget_id/budget_shares" do
    let(:valid_params) do
      {
        budget_share: {
          name: "For accountant",
          show_budget: true,
          show_income_sources: true,
          show_personal_savings: false
        }
      }
    end

    it "creates a new share" do
      expect {
        post budget_budget_shares_path(budget), params: valid_params
      }.to change(BudgetShare, :count).by(1)
    end

    it "returns the share with token" do
      post budget_budget_shares_path(budget), params: valid_params, as: :turbo_stream
      expect(response).to have_http_status(:ok)
    end

    context "when not the budget owner" do
      let(:other_user) { create(:user) }
      before { sign_in(other_user) }

      it "denies access" do
        post budget_budget_shares_path(budget), params: valid_params
        expect(response).to redirect_to(budgets_path)
      end
    end
  end

  describe "DELETE /budgets/:budget_id/budget_shares/:id" do
    let!(:share) { create(:budget_share, monthly_budget: budget) }

    it "deletes the share" do
      expect {
        delete budget_budget_share_path(budget, share)
      }.to change(BudgetShare, :count).by(-1)
    end

    context "when not the budget owner" do
      let(:other_user) { create(:user) }
      before { sign_in(other_user) }

      it "denies access" do
        delete budget_budget_share_path(budget, share)
        expect(response).to redirect_to(budgets_path)
      end
    end
  end
end
