class IncomeSource < ApplicationRecord
  CURRENCIES = %w[CRC USD].freeze
  INCOME_TYPES = %w[hourly fixed].freeze

  belongs_to :user
  belongs_to :linked_user, class_name: "User", optional: true

  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: CURRENCIES }
  validates :income_type, presence: true, inclusion: { in: INCOME_TYPES }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }

  def amount_for_month(year, month)
    if income_type == "fixed"
      amount || 0
    elsif linked_user.present?
      entry = linked_user.salary_entries.find_by(year: year, month: month)
      entry ? (entry.hours_worked * entry.hourly_rate) : 0
    else
      0
    end
  end
end
