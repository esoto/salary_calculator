require 'rails_helper'

RSpec.describe PasswordsMailer, type: :mailer do
  describe '#reset' do
    let(:user) { create(:user, email_address: 'user@example.com') }
    let(:mail) { PasswordsMailer.reset(user) }

    it 'sends to correct email address' do
      expect(mail.to).to eq([user.email_address])
    end

    it 'has correct subject' do
      expect(mail.subject).to eq('Reset your password')
    end

    it 'includes reset link with token' do
      expect(mail.body.encoded).to include('password reset page')
      expect(mail.body.encoded).to match(%r{passwords/[^/]+/edit})
    end

    it 'mentions 15 minute expiration' do
      expect(mail.body.encoded).to include('15 minutes')
    end
  end
end
