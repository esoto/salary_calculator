class MonthlyBudget < ApplicationRecord
  include CurrencyPrecision

  has_paper_trail

  belongs_to :user
  has_many :budget_items, dependent: :destroy

  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :month, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 },
                    uniqueness: { scope: [ :user_id, :year ] }
  validates :exchange_rate, presence: true,
                            numericality: { greater_than: 0 }

  scope :for_year, ->(year) { where(year: year) }
  scope :ordered, -> { order(year: :desc, month: :desc) }

  DEFAULT_EXCHANGE_RATE = 503

  CATEGORY_DISPLAY_NAMES = {
    "fixed" => "Fixed Expenses",
    "guilt_free" => "Guilt-Free",
    "savings" => "Savings",
    "investments" => "Investments"
  }.freeze

  CATEGORY_TARGETS = {
    "fixed" => { min: 50, max: 60 }.freeze,
    "guilt_free" => { min: 20, max: 35 }.freeze,
    "savings" => { min: 5, max: 10 }.freeze,
    "investments" => { min: 10, max: 10 }.freeze
  }.freeze

  def total_income_usd
    user.income_sources.active.with_salary_data.sum do |source|
      amount = source.amount_for_month(year, month)
      source.usd? ? amount : (amount / exchange_rate)
    end
  end

  def category_total_usd(category)
    budget_items.where(category: category).sum(&:amount_in_usd)
  end

  def category_percentage(category)
    return 0.0 if total_income_usd.zero?
    ((category_total_usd(category) / total_income_usd) * 100).round(PERCENTAGE_DECIMAL_PLACES)
  end

  def total_expenses_usd
    budget_items.sum(&:amount_in_usd)
  end

  def category_status(category)
    percentage = category_percentage(category)
    target = CATEGORY_TARGETS[category]
    return :ok unless target

    if percentage < target[:min]
      percentage >= target[:min] - 5 ? :warning : :low
    elsif percentage > target[:max]
      percentage <= target[:max] + 5 ? :warning : :high
    else
      :ok
    end
  end

  def copy_items_from(source_budget)
    source_budget.budget_items.each do |item|
      budget_items.create!(
        item.attributes.slice("name", "category", "amount", "currency", "position")
      )
    end
  end

  def owned_by?(check_user)
    user_id == check_user.id
  end

  def accessible_by?(check_user)
    return true if owned_by?(check_user)
    return false unless shared_with_household?

    check_user.shares_household_with?(user)
  end

  def editable_by?(check_user)
    accessible_by?(check_user)
  end

  def recent_activity(limit: 10)
    budget_versions = versions.order(created_at: :desc).limit(limit)
    item_versions = PaperTrail::Version
      .where(item_type: "BudgetItem")
      .where(item_id: budget_items.pluck(:id))
      .order(created_at: :desc)
      .limit(limit)

    (budget_versions + item_versions)
      .sort_by(&:created_at)
      .reverse
      .first(limit)
  end
end
