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

  def self.yearly_summary(year)
    entries = for_year(year)

    total_earnings = entries.sum("hours_worked * hourly_rate")
    total_aguinaldo = entries.sum("hours_worked * hourly_rate / 12.0")
    total_vacation = entries.sum("#{VACATION_HOURS_PER_MONTH} * hourly_rate")
    total_holidays = entries.sum("#{HOLIDAY_HOURS_PER_MONTH} * hourly_rate")

    {
      total_earnings: total_earnings,
      total_aguinaldo: total_aguinaldo,
      total_vacation: total_vacation,
      total_holidays: total_holidays,
      total_savings: total_aguinaldo + total_vacation + total_holidays,
      entries_count: entries.count
    }
  end
end
