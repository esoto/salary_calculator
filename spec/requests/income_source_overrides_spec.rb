require "rails_helper"

RSpec.describe "IncomeSourceOverrides", type: :request do
  let(:household) { create(:household) }
  let(:owner)     { create(:user) }
  let(:member)    { create(:user) }
  let(:outsider)  { create(:user) }

  let(:budget) { create(:monthly_budget, user: owner, year: 2026, month: 4) }
  let(:source) { create(:income_source, user: owner, income_type: "fixed", amount: 1000) }

  before do
    create(:household_membership, user: owner,  household: household)
    create(:household_membership, user: member, household: household)
  end

  describe "POST /budgets/:budget_id/income_source_overrides" do
    context "as the owner" do
      before { sign_in(owner) }

      it "creates a single_month override with budget's year/month (ignores client-supplied year/month)" do
        expect {
          post budget_income_source_overrides_path(budget),
               params: {
                 income_source_override: {
                   income_source_id: source.id,
                   amount: 1500,
                   scope: "single_month",
                   # tampering attempt — should be ignored
                   year: 2020,
                   month: 1
                 }
               }
        }.to change(IncomeSourceOverride, :count).by(1)

        override = IncomeSourceOverride.last
        expect(override.year).to eq(2026)
        expect(override.month).to eq(4)
        expect(override.amount).to eq(1500)
        expect(override.scope).to eq("single_month")
      end

      it "is idempotent per (source, year, month, scope)" do
        post budget_income_source_overrides_path(budget),
             params: { income_source_override: { income_source_id: source.id, amount: 1500, scope: "single_month" } }
        expect {
          post budget_income_source_overrides_path(budget),
               params: { income_source_override: { income_source_id: source.id, amount: 1700, scope: "single_month" } }
        }.not_to change(IncomeSourceOverride, :count)

        expect(IncomeSourceOverride.last.amount).to eq(1700)
      end

      it "rejects when source is not on this budget (IDOR)" do
        other_users_source = create(:income_source, user: outsider, income_type: "fixed")
        post budget_income_source_overrides_path(budget),
             params: { income_source_override: { income_source_id: other_users_source.id, amount: 999, scope: "single_month" } }

        expect(response).to redirect_to(budget_path(budget))
        expect(flash[:alert]).to match(/not on this budget/i)
        expect(IncomeSourceOverride.count).to eq(0)
      end

      it "rejects when income source is not fixed type" do
        hourly = create(:income_source, user: owner, income_type: "hourly", amount: nil, linked_user: owner)
        post budget_income_source_overrides_path(budget),
             params: { income_source_override: { income_source_id: hourly.id, amount: 500, scope: "single_month" } }

        expect(response).to redirect_to(budget_path(budget))
        expect(flash[:alert]).to be_present
      end

      it "responds with Turbo Stream actions that replace the card and summary bar" do
        post budget_income_source_overrides_path(budget),
             params: { income_source_override: { income_source_id: source.id, amount: 1500, scope: "single_month" } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include(%(turbo-stream action="replace" target="budget_card_income_source_#{source.id}"))
        expect(response.body).to include(%(turbo-stream action="replace" target="budget-summary-bar"))
      end
    end

    context "as a household member viewing a shared budget" do
      before do
        budget.update!(shared_with_household: true)
        sign_in(member)
      end

      it "is rejected (cannot edit another user's income source)" do
        post budget_income_source_overrides_path(budget),
             params: { income_source_override: { income_source_id: source.id, amount: 999, scope: "single_month" } }

        expect(response).to redirect_to(budget_path(budget))
        expect(flash[:alert]).to match(/cannot modify/i)
        expect(IncomeSourceOverride.count).to eq(0)
      end
    end

    context "as an unrelated user" do
      before { sign_in(outsider) }

      it "cannot access the budget at all" do
        post budget_income_source_overrides_path(budget),
             params: { income_source_override: { income_source_id: source.id, amount: 999, scope: "single_month" } }

        expect(response).to redirect_to(budgets_path)
        expect(flash[:alert]).to match(/access denied/i)
      end
    end
  end

  describe "DELETE /budgets/:budget_id/income_source_overrides/:id" do
    let!(:override) do
      create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 1500, scope: "single_month")
    end

    context "as the owner" do
      before { sign_in(owner) }

      it "destroys the override" do
        expect {
          delete budget_income_source_override_path(budget, override)
        }.to change(IncomeSourceOverride, :count).by(-1)
      end

      it "rejects when override's source is not on this budget (IDOR)" do
        rogue_source = create(:income_source, user: outsider, income_type: "fixed")
        rogue_override = create(:income_source_override, income_source: rogue_source)

        delete budget_income_source_override_path(budget, rogue_override)

        expect(response).to redirect_to(budget_path(budget))
        expect(flash[:alert]).to match(/not on this budget/i)
        expect { rogue_override.reload }.not_to raise_error
      end

      it "rejects when override's year/month doesn't match the budget's month" do
        # Same source, but an override for a different month
        other_month_override = create(:income_source_override,
                                      income_source: source, year: 2026, month: 8, amount: 1800, scope: "single_month")

        delete budget_income_source_override_path(budget, other_month_override)

        expect(response).to redirect_to(budget_path(budget))
        expect(flash[:alert]).to match(/different month/i)
        expect { other_month_override.reload }.not_to raise_error
      end

      it "responds with Turbo Stream actions that replace the card and summary bar" do
        delete budget_income_source_override_path(budget, override),
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include(%(turbo-stream action="replace" target="budget_card_income_source_#{source.id}"))
        expect(response.body).to include(%(turbo-stream action="replace" target="budget-summary-bar"))
      end
    end

    context "as a household member" do
      before do
        budget.update!(shared_with_household: true)
        sign_in(member)
      end

      it "cannot destroy another user's override" do
        expect {
          delete budget_income_source_override_path(budget, override)
        }.not_to change(IncomeSourceOverride, :count)
        expect(flash[:alert]).to match(/cannot modify/i)
      end
    end
  end

  describe "flow: from_this_month applies to target month onward" do
    before { sign_in(owner) }

    it "affects current and future budgets but not past ones" do
      current_budget = create(:monthly_budget, user: owner, year: 2026, month: 4)

      # Create from_this_month override via current April budget
      post budget_income_source_overrides_path(current_budget),
           params: { income_source_override: { income_source_id: source.id, amount: 1200, scope: "from_this_month" } }

      expect(source.reload.amount_for_month(2026, 3)).to eq(1000)  # past unchanged
      expect(source.amount_for_month(2026, 4)).to eq(1200)          # current overridden
      expect(source.amount_for_month(2026, 5)).to eq(1200)          # future overridden
    end
  end

  describe "flow: destroying override reverts amount" do
    before { sign_in(owner) }

    it "reverts the source's effective amount to base after override destroyed" do
      post budget_income_source_overrides_path(budget),
           params: { income_source_override: { income_source_id: source.id, amount: 1500, scope: "single_month" } }

      expect(source.reload.amount_for_month(2026, 4)).to eq(1500)

      override = IncomeSourceOverride.last
      delete budget_income_source_override_path(budget, override)

      # Reload the association
      source.income_source_overrides.reload
      expect(source.amount_for_month(2026, 4)).to eq(1000)
    end
  end
end
