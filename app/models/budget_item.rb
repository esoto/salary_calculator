class BudgetItem < ApplicationRecord
  include CurrencyPrecision

  has_paper_trail

  belongs_to :monthly_budget

  enum :category, {
    fixed: "fixed",
    guilt_free: "guilt_free",
    savings: "savings",
    investments: "investments"
  }, validate: true

  enum :currency, { crc: "CRC", usd: "USD" }, validate: true

  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }
  scope :ordered, -> { order(:position, :created_at) }

  def amount_in_usd
    return amount if usd?
    (amount / monthly_budget.exchange_rate).round(CURRENCY_DECIMAL_PLACES)
  end

  def amount_in_crc
    return amount if crc?
    (amount * monthly_budget.exchange_rate).round(CURRENCY_DECIMAL_PLACES)
  end
end
