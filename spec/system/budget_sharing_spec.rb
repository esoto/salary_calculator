# frozen_string_literal: true

require "rails_helper"

# NOTE: These tests use rack_test which does not support JavaScript.
# This verifies the HTML fallback behavior but does NOT test Turbo Stream/Stimulus features.
# Future improvement: Use driven_by(:selenium_chrome_headless) for full JS testing.

RSpec.describe "Budget Sharing", type: :system do
  let(:user) { create(:user) }
  let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 1) }

  before do
    driven_by(:rack_test)
  end

  describe "creating a share link" do
    before { sign_in(user) }

    it "shows share button on budget page" do
      visit budget_path(budget)
      expect(page).to have_button("Share")
    end

    it "creates a share link with budget details" do
      visit budget_path(budget)
      expect(page).to have_button("Share")

      fill_in "Name", with: "For accountant"
      check "Budget details (categories & items)"
      click_button "Create Share Link"

      expect(BudgetShare.count).to eq(1)
      expect(BudgetShare.last.name).to eq("For accountant")
      expect(BudgetShare.last.show_budget).to eq(true)
    end

    it "creates a share link with income sources" do
      visit budget_path(budget)

      fill_in "Name", with: "For partner"
      check "Income sources"
      click_button "Create Share Link"

      expect(BudgetShare.count).to eq(1)
      expect(BudgetShare.last.show_income_sources).to eq(true)
    end

    it "creates a share link with personal savings" do
      visit budget_path(budget)

      fill_in "Name", with: "For financial advisor"
      check "Personal savings"
      click_button "Create Share Link"

      expect(BudgetShare.count).to eq(1)
      expect(BudgetShare.last.show_personal_savings).to eq(true)
    end

    it "creates a share link without a name" do
      visit budget_path(budget)

      check "Budget details (categories & items)"
      click_button "Create Share Link"

      expect(BudgetShare.count).to eq(1)
      expect(BudgetShare.last.name).to be_blank
    end

    it "generates a unique token for each share" do
      visit budget_path(budget)

      fill_in "Name", with: "Share 1"
      check "Budget details (categories & items)"
      click_button "Create Share Link"

      visit budget_path(budget)

      fill_in "Name", with: "Share 2"
      check "Budget details (categories & items)"
      click_button "Create Share Link"

      shares = BudgetShare.where(monthly_budget: budget).order(:created_at)
      expect(shares.count).to eq(2)
      expect(shares.map(&:token).uniq.count).to eq(2)
    end
  end

  describe "viewing shared budget" do
    let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true) }

    it "shows shared budget without authentication" do
      visit shared_budget_path(share.token)

      expect(page).to have_content("Shared Budget")
      expect(page).to have_content("January 2026")
      expect(page).to have_content(user.name)
    end

    it "shows budget details when enabled" do
      create(:budget_item, monthly_budget: budget, name: "Rent", category: "fixed", amount: 1500)

      visit shared_budget_path(share.token)

      expect(page).to have_content("Exchange Rate")
      expect(page).to have_content("Total Income")
      expect(page).to have_content("Total Expenses")
      expect(page).to have_content("Remaining")
    end

    it "shows categories when budget details are enabled" do
      visit shared_budget_path(share.token)

      expect(page).to have_content("Fixed Expenses")
      expect(page).to have_content("Guilt-Free")
      expect(page).to have_content("Savings")
      expect(page).to have_content("Investments")
    end

    it "shows expired message for expired share" do
      share.update!(expires_at: 1.day.ago)

      visit shared_budget_path(share.token)

      expect(page).to have_content("Link expired")
    end

    it "shows 404 for invalid token" do
      visit shared_budget_path("invalid_token_12345")
      # RecordNotFound is handled and raises a 404
      expect(page.status_code).to eq(404)
    end
  end

  describe "revoking a share link" do
    let!(:share) { create(:budget_share, monthly_budget: budget, name: "Test share", show_budget: true) }

    before { sign_in(user) }

    it "removes the share link" do
      visit budget_path(budget)

      expect(page).to have_content("Test share")

      click_button "Revoke"

      expect(BudgetShare.count).to eq(0)
      expect(page).to have_current_path(budget_path(budget))
    end

    it "prevents viewing revoked share" do
      token = share.token

      visit budget_path(budget)
      click_button "Revoke"

      visit shared_budget_path(token)
      # RecordNotFound is handled and raises a 404
      expect(page.status_code).to eq(404)
    end
  end

  describe "share visibility options" do
    let!(:income_source) { create(:income_source, user: user, name: "Main Job", amount: 5000, currency: "USD") }

    context "with show_income_sources enabled" do
      let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true, show_income_sources: true) }

      it "shows income sources section" do
        visit shared_budget_path(share.token)
        expect(page).to have_content("Income Sources")
        expect(page).to have_content("Main Job")
      end
    end

    context "with show_income_sources disabled" do
      let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true, show_income_sources: false) }

      it "does not show income sources section" do
        visit shared_budget_path(share.token)
        expect(page).not_to have_content("Income Sources")
      end
    end

    context "with show_personal_savings enabled" do
      let!(:salary_entry) { create(:salary_entry, user: user, year: 2026, month: 1) }
      let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true, show_personal_savings: true) }

      it "shows personal savings section when salary data exists" do
        visit shared_budget_path(share.token)

        expect(page).to have_content("Personal Savings")
      end
    end

    context "with show_personal_savings disabled" do
      let!(:salary_entry) { create(:salary_entry, user: user, year: 2026, month: 1) }
      let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true, show_personal_savings: false) }

      it "does not show personal savings section" do
        visit shared_budget_path(share.token)
        expect(page).not_to have_content("Personal Savings")
      end
    end

    context "with show_budget disabled" do
      let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: false, show_income_sources: true) }

      it "does not show budget details but can show income sources" do
        visit shared_budget_path(share.token)

        # Budget details should not be shown
        expect(page).not_to have_content("Fixed Expenses")
        expect(page).not_to have_content("Guilt-Free")

        # Income sources should still be shown
        expect(page).to have_content("Income Sources")
        expect(page).to have_content("Main Job")
      end
    end
  end

  describe "non-owner cannot see share button" do
    let(:other_user) { create(:user, name: "Other User") }

    before { sign_in(other_user) }

    it "does not show share button for non-owner" do
      # Make budget accessible via household sharing
      household = create(:household)
      create(:household_membership, household: household, user: user)
      create(:household_membership, household: household, user: other_user)
      budget.update!(shared_with_household: true)

      visit budget_path(budget)
      expect(page).not_to have_button("Share")
    end

    it "shows read-only view for non-owner" do
      # Make budget accessible via household sharing
      household = create(:household)
      create(:household_membership, household: household, user: user)
      create(:household_membership, household: household, user: other_user)
      budget.update!(shared_with_household: true)

      visit budget_path(budget)

      expect(page).to have_content("January 2026")
      expect(page).not_to have_button("Share")
    end
  end

  describe "active scope" do
    let!(:active_share) { create(:budget_share, monthly_budget: budget, show_budget: true, expires_at: nil) }
    let!(:future_expiring_share) { create(:budget_share, monthly_budget: budget, show_budget: true, expires_at: 1.day.from_now) }
    let!(:expired_share) { create(:budget_share, monthly_budget: budget, show_budget: true, expires_at: 1.day.ago) }

    before { sign_in(user) }

    it "only shows active shares on budget page" do
      visit budget_path(budget)

      # Active and future-expiring shares should be visible
      expect(BudgetShare.active.count).to eq(2)
      expect(BudgetShare.active).to include(active_share)
      expect(BudgetShare.active).to include(future_expiring_share)
      expect(BudgetShare.active).not_to include(expired_share)
    end
  end

  describe "share token security" do
    let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true) }

    it "generates secure urlsafe base64 tokens" do
      expect(share.token).to be_present
      expect(share.token.length).to be >= 32
    end

    it "prevents token prediction by using unique tokens" do
      shares = create_list(:budget_share, 5, monthly_budget: budget, show_budget: true)
      tokens = shares.map(&:token)

      expect(tokens.uniq.count).to eq(5)
    end
  end

  describe "share display name" do
    context "with a custom name" do
      let!(:share) { create(:budget_share, monthly_budget: budget, name: "Accountant Review", show_budget: true) }

      it "displays the custom name" do
        expect(share.display_name).to eq("Accountant Review")
      end
    end

    context "without a custom name" do
      let!(:share) { create(:budget_share, monthly_budget: budget, name: nil, show_budget: true) }

      it "displays the default name with ID" do
        expect(share.display_name).to eq("Share link ##{share.id}")
      end
    end
  end

  describe "multiple shares per budget" do
    before { sign_in(user) }

    it "allows multiple different shares for the same budget" do
      visit budget_path(budget)

      # Create first share
      fill_in "Name", with: "For accountant"
      check "Budget details (categories & items)"
      click_button "Create Share Link"

      # Create second share with different settings
      visit budget_path(budget)
      fill_in "Name", with: "For partner"
      check "Income sources"
      click_button "Create Share Link"

      # Create third share with different settings
      visit budget_path(budget)
      fill_in "Name", with: "For advisor"
      check "Personal savings"
      click_button "Create Share Link"

      shares = BudgetShare.where(monthly_budget: budget).order(:created_at)
      expect(shares.count).to eq(3)
      expect(shares.map(&:name)).to contain_exactly("For accountant", "For partner", "For advisor")
    end
  end

  describe "share expiration" do
    let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true, expires_at: 7.days.from_now) }

    before { sign_in(user) }

    it "shows expiration date in share list" do
      visit budget_path(budget)

      expect(page).to have_content(share.expires_at.strftime("%b %d, %Y"))
    end

    it "marks share as not expired when expiration is in future" do
      expect(share.expired?).to be false
    end

    it "marks share as expired when expiration is in past" do
      share.update!(expires_at: 1.day.ago)
      expect(share.expired?).to be true
    end
  end
end
