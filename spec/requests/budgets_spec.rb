# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Budgets", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /budgets" do
    it "returns success" do
      get budgets_path
      expect(response).to have_http_status(:success)
    end

    it "shows user's budgets" do
      create(:monthly_budget, user: user, month: 1)
      get budgets_path
      expect(response.body).to include("January #{Date.current.year}")
    end

    context "with household member" do
      let(:household) { create(:household) }
      let(:partner) { create(:user, name: "Partner") }

      before do
        create(:household_membership, household: household, user: user)
        create(:household_membership, household: household, user: partner)
      end

      it "shows household member budgets" do
        create(:monthly_budget, user: partner, month: 1)
        get budgets_path
        expect(response.body).to include("Partner")
      end
    end
  end

  describe "GET /budgets/:id" do
    let(:budget) { create(:monthly_budget, user: user) }

    it "returns success" do
      get budget_path(budget)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /budgets/new" do
    it "returns success" do
      get new_budget_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /budgets" do
    let(:valid_params) { { monthly_budget: { year: Date.current.year, month: 3, exchange_rate: 503 } } }

    it "creates a budget" do
      expect {
        post budgets_path, params: valid_params
      }.to change(MonthlyBudget, :count).by(1)
    end

    it "redirects to the new budget" do
      post budgets_path, params: valid_params
      expect(response).to redirect_to(budget_path(MonthlyBudget.last))
    end

    it "copies items from previous month" do
      previous = create(:monthly_budget, user: user, month: 2)
      create(:budget_item, monthly_budget: previous, name: "Rent", amount: 1000)

      post budgets_path, params: valid_params
      new_budget = MonthlyBudget.last
      expect(new_budget.budget_items.pluck(:name)).to include("Rent")
    end
  end

  describe "GET /budgets/:id/edit" do
    let(:budget) { create(:monthly_budget, user: user) }

    it "returns success" do
      get edit_budget_path(budget)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /budgets/:id" do
    let(:budget) { create(:monthly_budget, user: user) }

    it "updates the budget" do
      patch budget_path(budget), params: { monthly_budget: { exchange_rate: 510 } }
      expect(budget.reload.exchange_rate).to eq(510)
    end

    it "redirects to the budget" do
      patch budget_path(budget), params: { monthly_budget: { exchange_rate: 510 } }
      expect(response).to redirect_to(budget_path(budget))
    end
  end

  describe "DELETE /budgets/:id" do
    let!(:budget) { create(:monthly_budget, user: user) }

    it "deletes the budget" do
      expect {
        delete budget_path(budget)
      }.to change(MonthlyBudget, :count).by(-1)
    end

    it "redirects to index" do
      delete budget_path(budget)
      expect(response).to redirect_to(budgets_path)
    end
  end

  describe "access control" do
    let(:other_user) { create(:user) }
    let(:other_budget) { create(:monthly_budget, user: other_user, shared_with_household: true) }

    it "denies access to non-household member budget" do
      get budget_path(other_budget)
      expect(response).to redirect_to(budgets_path)
    end

    context "with household member" do
      let(:household) { create(:household) }

      before do
        create(:household_membership, household: household, user: user)
        create(:household_membership, household: household, user: other_user)
      end

      it "allows access to household member budget" do
        get budget_path(other_budget)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "access control with sharing" do
    let(:household) { create(:household) }
    let(:owner) { create(:user) }
    let(:partner) { create(:user) }
    let(:stranger) { create(:user) }

    before do
      create(:household_membership, household: household, user: owner)
      create(:household_membership, household: household, user: partner)
    end

    describe "private budget" do
      let!(:budget) { create(:monthly_budget, user: owner, shared_with_household: false) }

      it "allows owner to view" do
        sign_in(owner)
        get budget_path(budget)
        expect(response).to have_http_status(:success)
      end

      it "denies household member access" do
        sign_in(partner)
        get budget_path(budget)
        expect(response).to redirect_to(budgets_path)
      end

      it "denies stranger access" do
        sign_in(stranger)
        get budget_path(budget)
        expect(response).to redirect_to(budgets_path)
      end
    end

    describe "shared budget" do
      let!(:budget) { create(:monthly_budget, user: owner, shared_with_household: true) }

      it "allows owner to view" do
        sign_in(owner)
        get budget_path(budget)
        expect(response).to have_http_status(:success)
      end

      it "allows household member to view" do
        sign_in(partner)
        get budget_path(budget)
        expect(response).to have_http_status(:success)
      end

      it "denies stranger access" do
        sign_in(stranger)
        get budget_path(budget)
        expect(response).to redirect_to(budgets_path)
      end
    end

    describe "delete protection" do
      let!(:budget) { create(:monthly_budget, user: owner, shared_with_household: true) }

      it "allows owner to delete" do
        sign_in(owner)
        delete budget_path(budget)
        expect(response).to redirect_to(budgets_path)
        expect(MonthlyBudget.exists?(budget.id)).to be false
      end

      it "denies household member from deleting" do
        sign_in(partner)
        delete budget_path(budget)
        expect(response).to redirect_to(budgets_path)
        expect(MonthlyBudget.exists?(budget.id)).to be true
      end
    end
  end
end
