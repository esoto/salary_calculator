require "rails_helper"

RSpec.describe "ConnectedApps", type: :request do
  let(:user) { create(:user) }
  let!(:token) { ApiToken.create!(user: user, name: "Expense Tracker", scopes: "budget:read") }

  before { sign_in(user) }

  describe "GET /connected_apps" do
    it "lists the user's active tokens" do
      get connected_apps_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Expense Tracker")
      expect(response.body).to include("budget:read")
    end

    it "does not list other users' tokens" do
      other = create(:user)
      ApiToken.create!(user: other, name: "Someone Else", scopes: "budget:read")
      get connected_apps_path
      expect(response.body).not_to include("Someone Else")
    end
  end

  describe "DELETE /connected_apps/:id" do
    it "revokes (deactivates) the token" do
      delete connected_app_path(token)
      expect(response).to redirect_to(connected_apps_path)
      expect(token.reload.active).to be false
    end

    it "rejects revoking another user's token" do
      other = create(:user)
      other_token = ApiToken.create!(user: other, name: "Theirs", scopes: "budget:read")
      delete connected_app_path(other_token)
      expect(response).to have_http_status(:not_found)
      expect(other_token.reload.active).to be true
    end
  end
end
