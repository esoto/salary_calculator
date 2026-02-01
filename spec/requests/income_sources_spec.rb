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
      source = create(:income_source, user: user, name: "Main Salary")
      get income_sources_path
      expect(response.body).to include("Main Salary")
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
end
