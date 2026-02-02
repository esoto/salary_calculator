# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in(user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: password }
  end
end

module SystemAuthenticationHelpers
  def sign_in(user, password: "password123")
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: password
    click_button "Log In"
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include SystemAuthenticationHelpers, type: :system
end
