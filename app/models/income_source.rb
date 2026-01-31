class IncomeSource < ApplicationRecord
  belongs_to :user
  belongs_to :linked_user, class_name: "User", optional: true

  enum :currency, { crc: "CRC", usd: "USD" }, validate: true
  enum :income_type, { hourly: "hourly", fixed: "fixed" }, validate: true

  validates :name, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }

  def amount_for_month(year, month)
    if fixed?
      amount || 0
    elsif linked_user.present?
      entry = linked_user.salary_entries.find_by(year: year, month: month)
      entry ? (entry.hours_worked * entry.hourly_rate) : 0
    else
      0
    end
  end
end
