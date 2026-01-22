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
end
