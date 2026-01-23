class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_digest
  end

  def password_reset_token
    generate_token_for(:password_reset)
  end
  has_many :sessions, dependent: :destroy
  has_many :salary_entries, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :default_hourly_rate, numericality: { greater_than: 0 }, allow_nil: true
  validates :vacation_days_per_year, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :holiday_days_per_year, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 30 }
  validates :hours_per_day, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
end
