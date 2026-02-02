# frozen_string_literal: true

require "rails_helper"

# NOTE: These tests use rack_test which does not support JavaScript.
# This verifies the HTML fallback behavior but does NOT test Turbo Stream features.
# Future improvement: Use driven_by(:selenium_chrome_headless) for full JS testing.

RSpec.describe "Income Sources Management", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    sign_in(user)
  end

  describe "income sources index" do
    it "shows the income sources page" do
      visit income_sources_path
      expect(page).to have_content("Income Sources")
      expect(page).to have_content("Manage your income for budget calculations")
    end

    it "shows a message when no income sources exist" do
      visit income_sources_path
      expect(page).to have_content("No income sources yet")
    end

    it "shows existing income sources" do
      create(:income_source, user: user, name: "Main Job", amount: 5000, currency: "usd")
      visit income_sources_path

      expect(page).to have_content("Main Job")
      expect(page).to have_content("$5,000.00")
    end
  end

  describe "creating income sources" do
    it "allows adding a fixed income source" do
      visit income_sources_path

      fill_in "Name", with: "Side Gig"
      select "Fixed (set amount)", from: "Income type"
      fill_in "Amount", with: "500"
      select "USD", from: "Currency"
      click_button "Add Income Source"

      expect(page).to have_content("Income source added")
      expect(page).to have_content("Side Gig")
      expect(page).to have_content("$500.00")
    end

    it "allows adding a CRC income source" do
      visit income_sources_path

      fill_in "Name", with: "Local Income"
      select "Fixed (set amount)", from: "Income type"
      fill_in "Amount", with: "250000"
      select "CRC (Colones)", from: "Currency"
      click_button "Add Income Source"

      expect(page).to have_content("Local Income")
      expect(page).to have_content("₡250,000")
    end

    it "shows validation errors for invalid input" do
      visit income_sources_path

      fill_in "Name", with: ""
      click_button "Add Income Source"

      expect(page).to have_content("Name can't be blank")
    end
  end

  describe "income source types" do
    it "shows fixed type label" do
      create(:income_source, user: user, name: "Salary", income_type: "fixed", amount: 5000)
      visit income_sources_path

      expect(page).to have_content("Fixed")
    end

    it "shows hourly type label" do
      create(:income_source, user: user, name: "Contract Work", income_type: "hourly", linked_user: user)
      visit income_sources_path

      expect(page).to have_content("Hourly")
      expect(page).to have_content("From salary")
    end
  end

  describe "activating and deactivating" do
    let!(:source) { create(:income_source, user: user, name: "Main Job", active: true) }

    it "allows deactivating an income source" do
      visit income_sources_path

      click_button "Deactivate"

      expect(page).to have_content("Inactive")
      expect(page).to have_button("Activate")
    end

    it "allows reactivating an income source" do
      source.update!(active: false)
      visit income_sources_path

      click_button "Activate"

      expect(page).to have_content("Active")
      expect(page).to have_button("Deactivate")
    end
  end

  describe "deleting income sources" do
    let!(:source) { create(:income_source, user: user, name: "Side Gig") }

    it "allows deleting an income source" do
      visit income_sources_path

      click_button "Delete"

      expect(page).to have_content("Income source removed")
      expect(page).not_to have_content("Side Gig")
    end
  end

  describe "linking to household members" do
    let(:household) { create(:household) }
    let(:partner) { create(:user, name: "Partner") }

    before do
      create(:household_membership, household: household, user: user)
      create(:household_membership, household: household, user: partner)
    end

    it "shows household members in the linked user dropdown" do
      visit income_sources_path

      expect(page).to have_select("Link to User", options: [ "None", user.name, "Partner" ])
    end
  end
end
