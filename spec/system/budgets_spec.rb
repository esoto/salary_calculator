# frozen_string_literal: true

require "rails_helper"

# NOTE: These tests use rack_test which does not support JavaScript.
# This verifies the HTML fallback behavior but does NOT test Turbo Stream/Stimulus features.
# Future improvement: Use driven_by(:selenium_chrome_headless) for full JS testing.

RSpec.describe "Budget Management", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    sign_in(user)
  end

  describe "budget index" do
    it "shows the budgets page" do
      visit budgets_path
      expect(page).to have_content("Budgets")
      expect(page).to have_content("Monthly budget planning")
    end

    it "shows a message when no budgets exist" do
      visit budgets_path
      expect(page).to have_content("No budgets for #{Date.current.year} yet")
    end

    it "shows user's budgets" do
      create(:monthly_budget, user: user, year: Date.current.year, month: 1)
      visit budgets_path
      expect(page).to have_content("January #{Date.current.year}")
    end

    it "allows filtering by year" do
      create(:monthly_budget, user: user, year: 2025, month: 6)
      create(:monthly_budget, user: user, year: 2026, month: 3)

      visit budgets_path(year: 2025)
      expect(page).to have_content("June 2025")
      expect(page).not_to have_content("March 2026")
    end
  end

  describe "creating a budget" do
    it "allows user to create a new budget" do
      visit budgets_path
      click_link "New Budget"

      expect(page).to have_content("New Budget")

      select "2026", from: "Year"
      select "March", from: "Month"
      fill_in "Exchange Rate", with: "510"
      click_button "Create Budget"

      expect(page).to have_content("March 2026")
      expect(page).to have_content("Budget created successfully")
    end

    it "shows validation errors for invalid input" do
      visit new_budget_path
      fill_in "Exchange Rate", with: ""
      click_button "Create Budget"

      expect(page).to have_content("error")
    end

    it "copies items from previous month when creating" do
      previous = create(:monthly_budget, user: user, year: 2026, month: 2)
      create(:budget_item, monthly_budget: previous, name: "Netflix", amount: 15.99, category: "fixed")

      visit new_budget_path(year: 2026, month: 3)
      fill_in "Exchange Rate", with: "503"
      click_button "Create Budget"

      expect(page).to have_content("Netflix")
    end
  end

  describe "viewing a budget" do
    let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 1, exchange_rate: 500) }

    it "shows budget details" do
      visit budget_path(budget)

      expect(page).to have_content("January 2026")
      expect(page).to have_content("Exchange Rate")
      expect(page).to have_content("500")
    end

    it "shows category columns" do
      visit budget_path(budget)

      expect(page).to have_content("Fixed Expenses")
      expect(page).to have_content("Guilt-Free")
      expect(page).to have_content("Savings")
      expect(page).to have_content("Investments")
    end

    it "shows budget items in their categories" do
      create(:budget_item, monthly_budget: budget, name: "Rent", category: "fixed", amount: 1500)
      create(:budget_item, monthly_budget: budget, name: "Dining Out", category: "guilt_free", amount: 200)

      visit budget_path(budget)

      expect(page).to have_content("Rent")
      expect(page).to have_content("Dining Out")
    end
  end

  describe "editing a budget" do
    let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 1, exchange_rate: 500) }

    it "allows editing budget settings" do
      visit budget_path(budget)
      click_link "Edit Settings"

      fill_in "Exchange Rate", with: "520"
      click_button "Update Budget"

      expect(page).to have_content("Budget updated successfully")
    end
  end

  describe "deleting a budget" do
    let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 1) }

    it "allows deleting a budget" do
      visit edit_budget_path(budget)

      # rack_test doesn't support JS confirms, but the form still submits
      click_button "Delete Budget"

      expect(page).to have_content("Budget deleted")
      expect(page).to have_current_path(budgets_path)
    end
  end

  describe "household sharing" do
    let(:household) { create(:household) }
    let(:partner) { create(:user, name: "Partner") }

    before do
      create(:household_membership, household: household, user: user)
      create(:household_membership, household: household, user: partner)
    end

    it "shows partner's budgets in household section" do
      create(:monthly_budget, user: partner, year: Date.current.year, month: 1)

      visit budgets_path
      expect(page).to have_content("Household Budgets")
      expect(page).to have_content("Partner")
    end

    it "allows viewing partner's budget" do
      partner_budget = create(:monthly_budget, user: partner, year: 2026, month: 2)

      visit budget_path(partner_budget)
      expect(page).to have_content("February 2026")
      expect(page).to have_content("Partner's Budget")
    end
  end

  describe "access control" do
    let(:other_user) { create(:user) }
    let(:other_budget) { create(:monthly_budget, user: other_user) }

    it "denies access to non-household member budget" do
      visit budget_path(other_budget)
      expect(page).to have_current_path(budgets_path)
      expect(page).to have_content("Access denied")
    end
  end
end
