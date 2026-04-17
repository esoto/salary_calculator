class IncomeSource < ApplicationRecord
  belongs_to :user
  belongs_to :linked_user, class_name: "User", optional: true

  has_many :income_source_overrides, dependent: :destroy

  enum :currency, { crc: "CRC", usd: "USD" }, validate: true
  enum :income_type, { hourly: "hourly", fixed: "fixed" }, validate: true

  validates :name, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :with_salary_data, -> { includes(linked_user: :salary_entries) }
  scope :with_override_data, -> { includes(:income_source_overrides) }

  def amount_for_month(year, month)
    if fixed?
      override_amount_for(year, month) || amount || 0
    elsif linked_user.present?
      # Use previous month's salary entry since current month's salary is unknown
      prev_year, prev_month = month == 1 ? [ year - 1, 12 ] : [ year, month - 1 ]
      # Use detect to leverage preloaded salary_entries from with_salary_data scope
      entry = linked_user.salary_entries.detect { |e| e.year == prev_year && e.month == prev_month }
      # Use net_pay (take-home after savings deductions) for budget calculations
      # This reflects actual available income for household budgeting
      entry ? entry.net_pay : 0
    else
      0
    end
  end

  def owned_by?(check_user)
    user_id == check_user.id
  end

  def accessible_by?(check_user)
    return true if owned_by?(check_user)

    # Linked users can access income sources that use their salary data
    return true if linked_user_id == check_user.id

    # Accessible if owner has any shared budget and users share a household
    user.monthly_budgets.where(shared_with_household: true).exists? &&
      check_user.shares_household_with?(user)
  end

  def editable_by?(check_user)
    return true if owned_by?(check_user)
    return true if linked_user_id.present? && linked_user_id == check_user.id
    false
  end

  private

  def override_amount_for(year, month)
    single = income_source_overrides
      .detect { |o| o.single_month? && o.year == year && o.month == month }
    return single.amount if single

    ongoing = income_source_overrides
      .select { |o| o.from_this_month? }
      .select { |o| (o.year < year) || (o.year == year && o.month <= month) }
      .max_by { |o| [ o.year, o.month ] }
    ongoing&.amount
  end
end
