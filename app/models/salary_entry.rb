class SalaryEntry < ApplicationRecord
  include SalaryCalculations

  scope :for_year, ->(year) { where(year: year) }
  scope :ordered, -> { order(:year, :month) }

  validates :month, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :hours_worked, presence: true,
                           numericality: { greater_than: 0 }
  validates :hourly_rate, presence: true,
                          numericality: { greater_than: 0 }
  validates :month, uniqueness: { scope: :year }

  def self.yearly_summary(year)
    entries = for_year(year)

    {
      total_earnings: entries.sum(&:monthly_salary),
      total_aguinaldo: entries.sum(&:aguinaldo_savings),
      total_vacation: entries.sum(&:vacation_savings),
      total_holidays: entries.sum(&:holiday_savings),
      total_savings: entries.sum(&:total_savings),
      entries_count: entries.count
    }
  end
end
