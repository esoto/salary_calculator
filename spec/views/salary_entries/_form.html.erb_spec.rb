require "rails_helper"

RSpec.describe "salary_entries/_form", type: :view do
  before do
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(user)
    end
  end

  describe "vacation_days_taken field" do
    context "when vacation is enabled" do
      let(:user) { create(:user, vacation_enabled: true) }
      let(:entry) { user.salary_entries.build }

      it "shows vacation_days_taken" do
        render partial: "salary_entries/form", locals: { salary_entry: entry }
        expect(rendered).to include("Vacation days taken")
      end
    end

    context "when vacation is disabled" do
      let(:user) { create(:user, vacation_enabled: false) }
      let(:entry) { user.salary_entries.build }

      it "hides vacation_days_taken" do
        render partial: "salary_entries/form", locals: { salary_entry: entry }
        expect(rendered).not_to include("Vacation days taken")
      end
    end
  end

  describe "holiday_days_taken field" do
    context "when holiday is enabled" do
      let(:user) { create(:user, holiday_enabled: true) }
      let(:entry) { user.salary_entries.build }

      it "shows holiday_days_taken" do
        render partial: "salary_entries/form", locals: { salary_entry: entry }
        expect(rendered).to include("Holiday days taken")
      end
    end

    context "when holiday is disabled" do
      let(:user) { create(:user, holiday_enabled: false) }
      let(:entry) { user.salary_entries.build }

      it "hides holiday_days_taken" do
        render partial: "salary_entries/form", locals: { salary_entry: entry }
        expect(rendered).not_to include("Holiday days taken")
      end
    end
  end

  describe "vacation over-limit warning banner" do
    let(:user) { create(:user, vacation_enabled: true) }
    let(:salary_entry) { user.salary_entries.build(year: 2025, month: 1) }

    before do
      assign(:salary_entry, salary_entry)
    end

    context "when not over vacation limit" do
      before do
        assign(:over_vacation_limit, false)
      end

      it "does not show warning banner" do
        render partial: "salary_entries/form", locals: { salary_entry: salary_entry }
        expect(rendered).not_to have_css(".bg-amber-50")
        expect(rendered).not_to have_content("Vacation days warning")
      end
    end

    context "when over vacation limit" do
      before do
        assign(:over_vacation_limit, true)
        assign(:vacation_over_by, 2.5)
      end

      it "shows warning banner with correct message" do
        render partial: "salary_entries/form", locals: { salary_entry: salary_entry }
        expect(rendered).to have_css(".bg-amber-50")
        expect(rendered).to have_content("Vacation days warning")
        expect(rendered).to have_content("You're taking 2.5")
        expect(rendered).to have_content("more days than earned")
      end

      it "shows acknowledgment checkbox" do
        render partial: "salary_entries/form", locals: { salary_entry: salary_entry }
        expect(rendered).to have_field("salary_entry_vacation_over_limit_acknowledged")
        expect(rendered).to have_content("I understand this affects my savings")
      end
    end
  end
end
