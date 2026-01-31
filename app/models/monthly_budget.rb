class MonthlyBudget < ApplicationRecord
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

  CATEGORY_TARGETS = {
    "fixed" => { min: 50, max: 60 }.freeze,
    "guilt_free" => { min: 20, max: 35 }.freeze,
    "savings" => { min: 5, max: 10 }.freeze,
    "investments" => { min: 10, max: 10 }.freeze
  }.freeze

  # Warning: This triggers N+1 unless income_sources are eager loaded.
  # Use: user.income_sources.active.includes(linked_user: :salary_entries)
  def total_income_usd
    user.income_sources.active.sum do |source|
      amount = source.amount_for_month(year, month)
      source.usd? ? amount : (amount / exchange_rate)
    end
  end

  def category_total_usd(category)
    budget_items.where(category: category).sum(&:amount_in_usd)
  end

  def category_percentage(category)
    return 0.0 if total_income_usd.zero?
    ((category_total_usd(category) / total_income_usd) * 100).round(2)
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
end
