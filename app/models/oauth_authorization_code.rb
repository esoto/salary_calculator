require "digest"

class OauthAuthorizationCode < ApplicationRecord
  EXPIRATION = 60.seconds
  CODE_LENGTH = 32

  belongs_to :user

  validates :code_digest, presence: true, uniqueness: true
  validates :redirect_uri, presence: true
  validates :expires_at, presence: true

  IssueResult = Struct.new(:record, :plaintext, keyword_init: true)

  def self.issue(user:, redirect_uri:, scopes: "")
    plaintext = SecureRandom.urlsafe_base64(CODE_LENGTH)
    record = create!(
      user: user,
      code_digest: Digest::SHA256.hexdigest(plaintext),
      redirect_uri: redirect_uri,
      scopes: scopes,
      expires_at: EXPIRATION.from_now
    )
    IssueResult.new(record: record, plaintext: plaintext)
  end

  def self.consume(plaintext:, redirect_uri:)
    return nil if plaintext.blank?

    record = find_by(code_digest: Digest::SHA256.hexdigest(plaintext))
    return nil if record.nil?
    return nil if record.expires_at <= Time.current
    return nil if record.redirect_uri != redirect_uri

    affected = where(id: record.id, used_at: nil).update_all(used_at: Time.current)
    return nil if affected.zero?

    record.reload
  end
end
