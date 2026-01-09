# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    it "returns success" do
      get new_session_path
      expect(response).to have_http_status(:success)
    end

    it "displays forgot password link" do
      get new_session_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Forgot password?")
      expect(response.body).to include(new_password_path)
    end
  end
end
