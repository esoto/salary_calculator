require 'rails_helper'

RSpec.describe "Household Dashboard", type: :request do
  let(:user) { create(:user, password: 'password123', name: 'Alice') }

  before do
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe "GET /household" do
    context "when user is not in a household" do
      it "redirects to dashboard with message" do
        get household_path

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("not a member")
      end
    end

    context "when user is in a household" do
      let(:household) { create(:household, name: 'Smith Family') }
      let(:partner) { create(:user, name: 'Bob') }

      before do
        create(:household_membership, user: user, household: household)
        create(:household_membership, user: partner, household: household)
        create(:salary_entry, user: user, year: 2026, month: 1, hours_worked: 100, hourly_rate: 50)
        create(:salary_entry, user: partner, year: 2026, month: 1, hours_worked: 80, hourly_rate: 50)
      end

      it "shows household dashboard" do
        get household_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Smith Family')
      end

      it "shows combined earnings" do
        get household_path

        expect(response.body).to include('9,000') # 5000 + 4000
      end

      it "shows member breakdown" do
        get household_path

        expect(response.body).to include('Alice')
        expect(response.body).to include('Bob')
      end

      it "supports year selection" do
        create(:salary_entry, user: user, year: 2025, month: 1, hours_worked: 60, hourly_rate: 50)

        get household_path(year: 2025)

        expect(response.body).to include('3,000')
      end
    end
  end
end
