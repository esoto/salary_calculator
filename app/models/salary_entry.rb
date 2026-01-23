class SalaryEntry < ApplicationRecord
  include SalaryCalculations

  belongs_to :user

  scope :for_year, ->(year) { where(year: year) }
  scope :ordered, -> { order(:year, :month) }
  scope :for_aguinaldo_period, ->(year) {
    where("(year = ? AND month = 12) OR (year = ? AND month <= 11)", year - 1, year)
  }

  validates :month, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :hours_worked, presence: true,
                           numericality: { greater_than: 0 }
  validates :hourly_rate, presence: true,
                          numericality: { greater_than: 0 }
  validates :month, uniqueness: { scope: [ :year, :user_id ] }
  validates :vacation_days_taken, numericality: { greater_than_or_equal_to: 0 }
  validates :holiday_days_taken, numericality: { greater_than_or_equal_to: 0 }

  attr_accessor :vacation_over_limit_acknowledged

  validate :vacation_within_limit_or_acknowledged

  def self.yearly_summary(year)
    entries = for_year(year).includes(:user)

    total_earnings = entries.sum(&:monthly_salary)
    total_aguinaldo = entries.sum(&:aguinaldo_savings)
    total_vacation = entries.sum(&:vacation_savings)
    total_holidays = entries.sum(&:holiday_savings)

    {
      total_earnings: total_earnings,
      total_aguinaldo: total_aguinaldo,
      total_vacation: total_vacation,
      total_holidays: total_holidays,
      total_savings: total_aguinaldo + total_vacation + total_holidays,
      entries_count: entries.count
    }
  end

  private

  def vacation_within_limit_or_acknowledged
    return unless user&.vacation_enabled
    return if vacation_days_taken.to_f <= 0

    balance = user.vacation_balance_for_year(year, exclude_entry: self)
    return if balance[:balance] >= 0
    return if vacation_over_limit_acknowledged.present?

    errors.add(:base, "You're taking more vacation days than earned. Please acknowledge this to continue.")
  end
end
