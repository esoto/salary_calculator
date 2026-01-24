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

  attr_accessor :current_password

  validate :current_password_correct, if: :password_change_requested?

  def vacation_balance_for_year(year, exclude_entry: nil)
    entries = salary_entries.for_year(year)
    entries = entries.where.not(id: exclude_entry.id) if exclude_entry&.persisted?

    entries_count = entries.count
    entries_count += 1 if exclude_entry.present?

    days_earned = entries_count * (vacation_days_per_year / 12.0)
    days_taken = entries.sum(:vacation_days_taken)
    days_taken += exclude_entry.vacation_days_taken.to_f if exclude_entry.present?

    { earned: days_earned, taken: days_taken, balance: days_earned - days_taken }
  end

  private

  def password_change_requested?
    password.present? && password_digest_changed? && persisted? && !current_password_bypass_enabled?
  end

  def current_password_bypass_enabled?
    # Allow bypassing current_password validation if explicitly set to true
    @skip_current_password_validation == true
  end

  def current_password_correct
    if current_password.blank?
      errors.add(:current_password, "can't be blank")
    elsif BCrypt::Password.new(password_digest_was) != current_password
      errors.add(:current_password, "is incorrect")
    end
  end
end
