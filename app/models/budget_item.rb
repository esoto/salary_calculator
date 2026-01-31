class BudgetItem < ApplicationRecord
  CATEGORIES = %w[fixed guilt_free savings investments].freeze
  CURRENCIES = %w[CRC USD].freeze

  belongs_to :monthly_budget

  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true, inclusion: { in: CURRENCIES }

  scope :by_category, ->(category) { where(category: category) }
  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }
  scope :ordered, -> { order(:position, :created_at) }

  def amount_in_usd
    return amount if currency == "USD"
    (amount / monthly_budget.exchange_rate).round(2)
  end

  def amount_in_crc
    return amount if currency == "CRC"
    (amount * monthly_budget.exchange_rate).round(2)
  end
end
