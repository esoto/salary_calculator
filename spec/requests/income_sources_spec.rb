# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IncomeSources", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /income_sources" do
    it "returns success" do
      get income_sources_path
      expect(response).to have_http_status(:success)
    end

    it "shows user's income sources" do
      create(:income_source, user: user, name: "Main Salary")
      get income_sources_path
      expect(response.body).to include("Main Salary")
    end

    it "has income-source Stimulus controller for type toggle" do
      get income_sources_path
      expect(response.body).to include('data-controller="income-source"')
    end
  end

  describe "POST /income_sources" do
    let(:valid_params) do
      { income_source: { name: "Side Gig", amount: 500, currency: "USD", income_type: "fixed" } }
    end

    it "creates an income source" do
      expect {
        post income_sources_path, params: valid_params
      }.to change(IncomeSource, :count).by(1)
    end

    it "redirects to index" do
      post income_sources_path, params: valid_params
      expect(response).to redirect_to(income_sources_path)
    end

    context "with invalid params" do
      let(:invalid_params) do
        { income_source: { name: "", amount: 500, currency: "USD", income_type: "fixed" } }
      end

      it "does not create an income source" do
        expect {
          post income_sources_path, params: invalid_params
        }.not_to change(IncomeSource, :count)
      end

      it "renders index with errors" do
        post income_sources_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /income_sources/:id" do
    let(:source) { create(:income_source, user: user) }

    it "updates the source" do
      patch income_source_path(source), params: { income_source: { amount: 1000 } }
      expect(source.reload.amount).to eq(1000)
    end

    it "redirects to index" do
      patch income_source_path(source), params: { income_source: { amount: 1000 } }
      expect(response).to redirect_to(income_sources_path)
    end
  end

  describe "DELETE /income_sources/:id" do
    let!(:source) { create(:income_source, user: user) }

    it "deletes the source" do
      expect {
        delete income_source_path(source)
      }.to change(IncomeSource, :count).by(-1)
    end

    it "redirects to index" do
      delete income_source_path(source)
      expect(response).to redirect_to(income_sources_path)
    end
  end

  describe "access control" do
    let(:other_user) { create(:user) }
    let!(:other_source) { create(:income_source, user: other_user) }

    it "cannot update another user's income source" do
      patch income_source_path(other_source), params: { income_source: { amount: 9999 } }
      expect(response).to redirect_to(income_sources_path)
      expect(other_source.reload.amount).not_to eq(9999)
    end

    it "cannot delete another user's income source" do
      expect {
        delete income_source_path(other_source)
      }.not_to change(IncomeSource, :count)
    end
  end

  describe "household income sharing" do
    let(:household) { create(:household) }
    let(:partner) { create(:user) }
    let!(:partner_source) { create(:income_source, user: partner, name: "Partner Income") }

    before do
      create(:household_membership, household: household, user: user)
      create(:household_membership, household: household, user: partner)
    end

    context "when partner has no shared budgets" do
      it "does not show partner's income sources" do
        get income_sources_path
        expect(response.body).not_to include("Partner Income")
      end

      it "cannot update partner's income source" do
        patch income_source_path(partner_source), params: { income_source: { amount: 9999 } }
        expect(response).to redirect_to(income_sources_path)
        expect(partner_source.reload.amount).not_to eq(9999)
      end

      it "cannot delete partner's income source" do
        expect {
          delete income_source_path(partner_source)
        }.not_to change(IncomeSource, :count)
      end
    end

    context "when partner has shared budget" do
      before do
        create(:monthly_budget, user: partner, shared_with_household: true)
      end

      it "shows partner's income sources in household section" do
        get income_sources_path
        expect(response.body).to include("Partner Income")
        expect(response.body).to include("Household Income Sources")
      end

      it "can update partner's income source" do
        patch income_source_path(partner_source), params: { income_source: { amount: 9999 } }
        expect(response).to redirect_to(income_sources_path)
        expect(partner_source.reload.amount).to eq(9999)
      end

      it "can delete partner's income source" do
        expect {
          delete income_source_path(partner_source)
        }.to change(IncomeSource, :count).by(-1)
      end
    end

    context "creating income for household members" do
      it "can create income source for another household member" do
        params = {
          income_source: {
            name: "New Partner Income",
            amount: 2000,
            currency: "USD",
            income_type: "fixed",
            user_id: partner.id
          }
        }

        expect {
          post income_sources_path, params: params
        }.to change(partner.income_sources, :count).by(1)
      end

      it "cannot create income source for non-household member" do
        stranger = create(:user)
        params = {
          income_source: {
            name: "Stranger Income",
            amount: 2000,
            currency: "USD",
            income_type: "fixed",
            user_id: stranger.id
          }
        }

        post income_sources_path, params: params
        # Should default to current user, not stranger
        expect(stranger.income_sources.count).to eq(0)
        expect(user.income_sources.find_by(name: "Stranger Income")).to be_present
      end
    end

    context "linked income source authorization" do
      let!(:linked_source) { create(:income_source, user: partner, linked_user: user, income_type: "hourly") }

      it "linked user can edit income source linked to them" do
        patch income_source_path(linked_source), params: { income_source: { name: "Updated Name" } }
        expect(response).to redirect_to(income_sources_path)
        expect(linked_source.reload.name).to eq("Updated Name")
      end

      it "linked user can delete income source linked to them" do
        expect {
          delete income_source_path(linked_source)
        }.to change(IncomeSource, :count).by(-1)
      end
    end

    context "owner retains control when sharing" do
      before do
        create(:monthly_budget, user: user, shared_with_household: true)
      end

      let!(:my_source) { create(:income_source, user: user, name: "My Salary") }

      it "owner can still update their own shared income source" do
        patch income_source_path(my_source), params: { income_source: { amount: 5000 } }
        expect(response).to redirect_to(income_sources_path)
        expect(my_source.reload.amount).to eq(5000)
      end

      it "owner can still delete their own shared income source" do
        expect {
          delete income_source_path(my_source)
        }.to change(IncomeSource, :count).by(-1)
      end
    end
  end
end
