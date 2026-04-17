require "rails_helper"

RSpec.describe "Budget income overrides", type: :system do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user, year: 2026, month: 4) }
  let!(:source) { create(:income_source, user: user, income_type: "fixed", amount: 1000, name: "Rent Property") }

  before do
    driven_by(:rack_test)
    sign_in(user)
  end

  it "shows an Edit button next to each fixed income source" do
    visit budget_path(budget)
    within("[data-testid='income-source-#{source.id}']") do
      expect(page).to have_button("Edit")
      expect(page).not_to have_text("(adjusted)")
    end
  end

  it "shows the (adjusted) label when an override exists" do
    create(:income_source_override, income_source: source, year: 2026, month: 4, amount: 1500, scope: "single_month")

    visit budget_path(budget)
    within("[data-testid='income-source-#{source.id}']") do
      expect(page).to have_text("(adjusted)")
      expect(page).to have_text("$1,500")
    end
  end

  it "renders the override dialog markup on the page" do
    visit budget_path(budget)
    expect(page).to have_css("dialog#override-modal", visible: :all)
    within("dialog#override-modal", visible: :all) do
      expect(page).to have_css("input[type='radio'][value='single_month']", visible: :all)
      expect(page).to have_css("input[type='radio'][value='from_this_month']", visible: :all)
      expect(page).to have_selector("legend", text: "Apply this change to", visible: :all)
    end
  end

  it "does not show an Edit button for hourly income sources" do
    # Create a linked-user for the hourly source so it renders
    other = create(:user)
    hourly = create(:income_source, user: user, income_type: "hourly", amount: nil, linked_user: other, name: "Linked Hourly")
    create(:salary_entry, user: other, year: 2026, month: 3)

    visit budget_path(budget)
    within("[data-testid='income-source-#{hourly.id}']") do
      expect(page).not_to have_button("Edit")
    end
  end
end
