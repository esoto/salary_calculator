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

    it "shows shared badge and owner name when viewing shared budget" do
      partner_budget = create(:monthly_budget, user: partner, year: 2026, month: 3, shared_with_household: true)

      visit budget_path(partner_budget)

      expect(page).to have_content("Shared")
      expect(page).to have_content("Partner's Budget")
    end

    it "does not show shared badge on own budget" do
      own_budget = create(:monthly_budget, user: user, year: 2026, month: 4)

      visit budget_path(own_budget)

      expect(page).not_to have_content("Shared")
      expect(page).not_to have_content("#{user.name}'s Budget")
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

  describe "activity log" do
    let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 5) }

    it "shows recent activity section" do
      budget.update!(exchange_rate: 510)

      visit budget_path(budget)
      expect(page).to have_content("Recent Activity")
    end

    it "shows who made changes" do
      PaperTrail.request.whodunnit = user.id
      budget.update!(exchange_rate: 510)

      visit budget_path(budget)
      expect(page).to have_content("You")
      expect(page).to have_content("changed exchange rate")
    end
  end

  describe "personal savings" do
    let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 6) }

    context "when user has salary entry with all savings enabled" do
      # monthly_salary = 160 * 50 = $8,000
      # aguinaldo = $8,000 / 12 = $666.67
      # vacation = (12 days * 8 hours / 12 months) * $50 = $400
      # holiday = (6 days * 8 hours / 12 months) * $50 = $200
      # total = $1,266.67
      before do
        user.update!(aguinaldo_enabled: true, vacation_enabled: true, holiday_enabled: true,
                     vacation_days_per_year: 12, holiday_days_per_year: 6, hours_per_day: 8)
        create(:salary_entry, user: user, year: 2026, month: 6, hours_worked: 160, hourly_rate: 50)
      end

      it "shows personal savings section with correct amounts" do
        visit budget_path(budget)

        expect(page).to have_content("Personal Savings")
        expect(page).to have_content("Aguinaldo:")
        expect(page).to have_content("$666.67")
        expect(page).to have_content("Vacation:")
        expect(page).to have_content("$400.00")
        expect(page).to have_content("Holiday:")
        expect(page).to have_content("$200.00")
        expect(page).to have_content("Total:")
        expect(page).to have_content("$1,266.67")
      end
    end

    context "when user has only vacation savings enabled" do
      # vacation = (12 days * 8 hours / 12 months) * $50 = $400
      before do
        user.update!(aguinaldo_enabled: false, vacation_enabled: true, holiday_enabled: false,
                     vacation_days_per_year: 12, hours_per_day: 8)
        create(:salary_entry, user: user, year: 2026, month: 6, hours_worked: 160, hourly_rate: 50)
      end

      it "shows only vacation savings with correct total" do
        visit budget_path(budget)

        expect(page).to have_content("Personal Savings")
        expect(page).not_to have_content("Aguinaldo:")
        expect(page).to have_content("Vacation:")
        expect(page).not_to have_content("Holiday:")
        expect(page).to have_content("Total:")
        # Verify $400.00 appears twice: once for Vacation, once for Total
        expect(page).to have_content("$400.00", count: 2)
      end
    end

    context "when user has no salary entry for the month" do
      it "does not show personal savings section" do
        visit budget_path(budget)
        expect(page).not_to have_content("Personal Savings")
      end
    end

    context "when user has all savings disabled" do
      before do
        user.update!(aguinaldo_enabled: false, vacation_enabled: false, holiday_enabled: false)
        create(:salary_entry, user: user, year: 2026, month: 6, hours_worked: 160, hourly_rate: 50)
      end

      it "does not show personal savings section" do
        visit budget_path(budget)
        expect(page).not_to have_content("Personal Savings")
      end
    end
  end
end
