require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET / (home)" do
    it "returns success for unauthenticated visitors" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "displays landing page content" do
      get root_path
      expect(response.body).to include("Your salary,")
      expect(response.body).to include("simplified.")
      expect(response.body).to include("Get Started Free")
    end

    it "includes feature descriptions" do
      get root_path
      expect(response.body).to include("Salary &amp; Earnings").or include("Salary & Earnings")
      expect(response.body).to include("Smart Budgets")
      expect(response.body).to include("Household Sharing")
    end

    it "includes navigation links for unauthenticated users" do
      get root_path
      expect(response.body).to include("Log in")
      expect(response.body).to include("Sign up")
    end

    it "uses the landing layout" do
      get root_path
      expect(response.body).to include("Newsreader")
      expect(response.body).not_to include("bg-gray-100 min-h-screen")
    end

    context "when authenticated" do
      let(:user) { create(:user) }

      before do
        post session_path, params: { email_address: user.email_address, password: "password123" }
      end

      it "redirects to dashboard" do
        get root_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
