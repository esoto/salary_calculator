# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BudgetItems", type: :request do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  before { sign_in(user) }

  describe "POST /budgets/:budget_id/budget_items" do
    let(:valid_params) do
      { budget_item: { name: "Netflix", category: "fixed", amount: 15.99, currency: "USD" } }
    end

    it "creates a budget item" do
      expect {
        post budget_budget_items_path(budget), params: valid_params
      }.to change(BudgetItem, :count).by(1)
    end

    it "redirects to the budget" do
      post budget_budget_items_path(budget), params: valid_params
      expect(response).to redirect_to(budget_path(budget))
    end

    context "with invalid params" do
      let(:invalid_params) do
        { budget_item: { name: "", category: "fixed", amount: 15.99, currency: "USD" } }
      end

      it "does not create a budget item" do
        expect {
          post budget_budget_items_path(budget), params: invalid_params
        }.not_to change(BudgetItem, :count)
      end
    end
  end

  describe "PATCH /budgets/:budget_id/budget_items/:id" do
    let(:item) { create(:budget_item, monthly_budget: budget) }

    it "updates the item" do
      patch budget_budget_item_path(budget, item), params: { budget_item: { amount: 99.99 } }
      expect(item.reload.amount).to eq(99.99)
    end

    it "redirects to the budget" do
      patch budget_budget_item_path(budget, item), params: { budget_item: { amount: 99.99 } }
      expect(response).to redirect_to(budget_path(budget))
    end
  end

  describe "PATCH /budgets/:budget_id/budget_items/:id/toggle_paid" do
    let(:item) { create(:budget_item, monthly_budget: budget, paid: false) }

    it "toggles paid status from false to true" do
      patch toggle_paid_budget_budget_item_path(budget, item)
      expect(item.reload.paid).to be true
    end

    it "toggles paid status from true to false" do
      item.update!(paid: true)
      patch toggle_paid_budget_budget_item_path(budget, item)
      expect(item.reload.paid).to be false
    end

    it "redirects to the budget" do
      patch toggle_paid_budget_budget_item_path(budget, item)
      expect(response).to redirect_to(budget_path(budget))
    end
  end

  describe "DELETE /budgets/:budget_id/budget_items/:id" do
    let!(:item) { create(:budget_item, monthly_budget: budget) }

    it "deletes the item" do
      expect {
        delete budget_budget_item_path(budget, item)
      }.to change(BudgetItem, :count).by(-1)
    end

    it "redirects to the budget" do
      delete budget_budget_item_path(budget, item)
      expect(response).to redirect_to(budget_path(budget))
    end
  end

  describe "access control" do
    let(:other_user) { create(:user) }
    let(:other_budget) { create(:monthly_budget, user: other_user) }

    it "denies create access to non-household member budget" do
      post budget_budget_items_path(other_budget), params: { budget_item: { name: "Test", category: "fixed", amount: 10, currency: "USD" } }
      expect(response).to redirect_to(budgets_path)
    end

    context "with household member" do
      let(:household) { create(:household) }
      let(:shared_budget) { create(:monthly_budget, user: other_user, shared_with_household: true) }

      before do
        create(:household_membership, household: household, user: user)
        create(:household_membership, household: household, user: other_user)
      end

      it "allows create access to shared household member budget" do
        expect {
          post budget_budget_items_path(shared_budget), params: { budget_item: { name: "Test", category: "fixed", amount: 10, currency: "USD" } }
        }.to change(BudgetItem, :count).by(1)
      end

      it "denies create access to non-shared household member budget" do
        expect {
          post budget_budget_items_path(other_budget), params: { budget_item: { name: "Test", category: "fixed", amount: 10, currency: "USD" } }
        }.not_to change(BudgetItem, :count)
        expect(response).to redirect_to(budgets_path)
      end
    end
  end
end
