# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PasswordsMailer, type: :mailer do
  include ActiveSupport::Testing::TimeHelpers

  describe '#reset' do
    let(:user) { create(:user, email_address: 'user@example.com') }
    let(:token) { user.password_reset_token }
    let(:mail) { PasswordsMailer.reset(user) }

    around do |example|
      freeze_time { example.run }
    end

    it 'sends to correct email address' do
      expect(mail.to).to eq([ user.email_address ])
    end

    it 'has correct subject' do
      expect(mail.subject).to eq('Reset your password')
    end

    it 'includes reset link with token' do
      expect(mail.body.encoded).to include('password reset page')
      expect(mail.body.encoded).to include(edit_password_url(token))
    end

    it 'mentions 15 minute expiration' do
      expect(mail.body.encoded).to include('15 minutes')
    end
  end
end
