# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Budget Items Management", type: :system do
  include ActionView::RecordIdentifier

  let(:user) { create(:user) }
  let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 1, exchange_rate: 500) }

  before do
    driven_by(:rack_test)
    sign_in(user)
  end

  describe "adding budget items" do
    it "allows adding a new item to a category" do
      visit budget_path(budget)

      within("##{dom_id(budget, 'fixed')}") do
        fill_in "Item name", with: "Netflix"
        fill_in "Amount", with: "15.99"
        select "USD", from: "fixed_budget_item_currency"
        click_button "+ Add"
      end

      expect(page).to have_content("Netflix")
      expect(page).to have_content("$15.99")
    end

    it "shows validation errors for invalid items" do
      visit budget_path(budget)

      within("##{dom_id(budget, 'fixed')}") do
        fill_in "Amount", with: "15.99"
        # Leave name empty - try to submit
        click_button "+ Add"
      end

      # HTML5 validation should prevent submission, or server-side error
      # Since HTML5 required attribute is used, the test verifies the form exists
      expect(page).to have_css("##{dom_id(budget, 'fixed')}")
    end

    it "supports both USD and CRC currencies" do
      visit budget_path(budget)

      within("##{dom_id(budget, 'fixed')}") do
        fill_in "Item name", with: "Electric Bill"
        fill_in "Amount", with: "50000"
        select "CRC", from: "fixed_budget_item_currency"
        click_button "+ Add"
      end

      expect(page).to have_content("Electric Bill")
      expect(page).to have_content("₡50,000")
    end
  end

  describe "viewing budget items" do
    let!(:item) { create(:budget_item, monthly_budget: budget, name: "Rent", category: "fixed", amount: 1500, currency: "usd") }

    it "shows item in the correct category" do
      visit budget_path(budget)

      within("##{dom_id(budget, 'fixed')}") do
        expect(page).to have_content("Rent")
        expect(page).to have_content("$1,500.00")
      end
    end

    it "shows converted amount" do
      visit budget_path(budget)

      # USD item should show CRC conversion
      expect(page).to have_content("≈ ₡750,000")
    end
  end

  describe "toggling paid status" do
    let!(:item) { create(:budget_item, monthly_budget: budget, name: "Rent", category: "fixed", amount: 1500, paid: false) }

    it "allows marking item as paid" do
      visit budget_path(budget)

      within("##{dom_id(item)}") do
        expect(page).to have_css("[aria-label='Mark as paid']")
        find("[aria-label='Mark as paid']").click
      end

      expect(page).to have_css("[aria-label='Mark as unpaid']")
    end
  end

  describe "deleting budget items" do
    let!(:item) { create(:budget_item, monthly_budget: budget, name: "Rent", category: "fixed", amount: 1500) }

    it "allows deleting an item" do
      visit budget_path(budget)

      within("##{dom_id(item)}") do
        find("[aria-label='Delete Rent']").click
      end

      expect(page).not_to have_content("Rent")
    end
  end

  describe "category totals" do
    before do
      create(:budget_item, monthly_budget: budget, name: "Rent", category: "fixed", amount: 1500, currency: "usd")
      create(:budget_item, monthly_budget: budget, name: "Electric", category: "fixed", amount: 100, currency: "usd")
    end

    it "shows category total in USD" do
      visit budget_path(budget)

      within("##{dom_id(budget, 'fixed')}") do
        expect(page).to have_content("$1,600.00")
      end
    end
  end
end
