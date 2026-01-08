class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_digest
  end
  has_many :sessions, dependent: :destroy
  has_many :salary_entries, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :default_hourly_rate, numericality: { greater_than: 0 }, allow_nil: true
end
