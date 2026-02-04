class IncomeSource < ApplicationRecord
  belongs_to :user
  belongs_to :monthly_budget, optional: true
  belongs_to :linked_user, class_name: "User", optional: true

  enum :currency, { crc: "CRC", usd: "USD" }, validate: true
  enum :income_type, { hourly: "hourly", fixed: "fixed" }, validate: true

  validates :name, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :with_salary_data, -> { includes(linked_user: :salary_entries) }

  def amount_for_month(year, month)
    if fixed?
      amount || 0
    elsif linked_user.present?
      # Use detect to leverage preloaded salary_entries from with_salary_data scope
      entry = linked_user.salary_entries.detect { |e| e.year == year && e.month == month }
      entry ? (entry.hours_worked * entry.hourly_rate) : 0
    else
      0
    end
  end

  def owned_by?(check_user)
    user_id == check_user.id
  end

  def accessible_by?(check_user)
    return true if owned_by?(check_user)

    # Accessible if attached to a shared budget and users share a household
    monthly_budget&.shared_with_household? && check_user.shares_household_with?(user)
  end

  def editable_by?(check_user)
    # Linked income sources can only be edited by the linked user
    return linked_user_id == check_user.id if linked_user_id.present?

    accessible_by?(check_user)
  end
end
