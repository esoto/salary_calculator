require "digest"

class ApiToken < ApplicationRecord
  TOKEN_LENGTH = 32
  CACHE_EXPIRY = 1.minute

  attr_accessor :token

  belongs_to :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_hash, presence: true, uniqueness: true
  validates :active, inclusion: { in: [ true, false ] }
  validate :expires_at_in_future, if: :expires_at?, on: :create

  scope :active, -> { where(active: true) }
  scope :valid, -> { active.where("expires_at IS NULL OR expires_at > ?", Time.current) }

  before_validation :generate_token_if_blank, on: :create

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def valid_token?
    active? && !expired?
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def scope_list
    scopes.to_s.split(/\s+/).reject(&:blank?)
  end

  def has_scope?(scope)
    scope_list.include?(scope.to_s)
  end

  def self.authenticate(token_string)
    return nil if token_string.blank?

    token_hash = Digest::SHA256.hexdigest(token_string)
    cache_key = "api_token:#{token_hash}"

    cached_id = Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      candidate = find_by(token_hash: token_hash)

      if candidate && BCrypt::Password.new(candidate.token_digest) == token_string
        candidate.id
      end
    end

    return nil unless cached_id

    api_token = valid.find_by(id: cached_id)
    return nil unless api_token

    api_token.touch_last_used!
    api_token
  end

  def self.generate_secure_token
    SecureRandom.urlsafe_base64(TOKEN_LENGTH)
  end

  def inspect
    redacted = token.present? ? "[FILTERED]" : nil
    "#<#{self.class.name} id=#{id.inspect} user_id=#{user_id.inspect} name=#{name.inspect} token=#{redacted.inspect}>"
  end

  private

  def generate_token_if_blank
    return if token_digest.present?

    self.token = self.class.generate_secure_token
    self.token_digest = BCrypt::Password.create(token)
    self.token_hash = Digest::SHA256.hexdigest(token)
  end

  def expires_at_in_future
    return unless expires_at.present?
    errors.add(:expires_at, "must be in the future") if expires_at <= Time.current
  end
end
