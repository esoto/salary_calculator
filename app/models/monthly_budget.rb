class MonthlyBudget < ApplicationRecord
  include CurrencyPrecision

  has_paper_trail

  belongs_to :user
  has_many :budget_items, dependent: :destroy
  has_many :budget_shares, dependent: :destroy

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
    all_income_sources.sum do |source|
      amount = source.amount_for_month(year, month)
      source.usd? ? amount : (amount / exchange_rate)
    end
  end

  def all_income_sources
    sources = user.income_sources.active.with_salary_data.with_override_data.to_a

    # Include household members' income sources when budget is shared
    if shared_with_household? && user.household.present?
      household_sources = IncomeSource.active.with_salary_data.with_override_data
        .includes(:user)
        .joins(user: :household_membership)
        .where(household_memberships: { household_id: user.household_membership.household_id })
        .where.not(user_id: user.id)
        .to_a
      sources += household_sources
    end

    sources
  end

  def category_total_usd(category)
    budget_items.select { |i| i.category == category }.sum(&:amount_in_usd)
  end

  def category_percentage(category)
    return 0.0 if total_income_usd.zero?
    ((category_total_usd(category) / total_income_usd) * 100).round(PERCENTAGE_DECIMAL_PLACES)
  end

  def total_expenses_usd
    budget_items.sum(&:amount_in_usd)
  end

  EXPENSE_CATEGORIES = %w[fixed guilt_free].freeze
  SAVING_CATEGORIES = %w[savings investments].freeze

  def category_status(category)
    percentage = category_percentage(category)
    target = CATEGORY_TARGETS[category]
    return :ok unless target

    if EXPENSE_CATEGORIES.include?(category)
      # For expenses: under target is good, over target is bad
      if percentage <= target[:max]
        :ok
      elsif percentage <= target[:max] + 10
        :warning
      else
        :high
      end
    else
      # For savings/investments: under target is bad, over target is good
      if percentage >= target[:min]
        :ok
      elsif percentage > target[:min] - 5
        :warning
      else
        :low
      end
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
      .where(item_id: budget_items.select(:id))
      .includes(:item)
      .order(created_at: :desc)
      .limit(limit)

    source_ids = all_income_sources.map(&:id)
    override_versions = override_versions_for(source_ids, limit: limit)

    (budget_versions + item_versions + override_versions)
      .sort_by(&:created_at)
      .reverse
      .first(limit)
  end

  private

  # Collects PaperTrail versions for IncomeSourceOverrides tied to THIS budget's
  # (year, month). Live overrides are found by FK lookup; destroyed overrides are
  # gone from the table, so we also scan destroy versions and parse the pre-destroy
  # object to filter by income_source_id + year + month.
  def override_versions_for(source_ids, limit:)
    live_ids = IncomeSourceOverride
      .where(income_source_id: source_ids)
      .where(year: year, month: month)
      .pluck(:id)

    destroyed_ids = PaperTrail::Version
      .where(item_type: "IncomeSourceOverride", event: "destroy")
      .order(created_at: :desc)
      .limit(limit * 3) # bounded scan: enough headroom for a personal tool
      .select { |v|
        obj = parse_paper_trail_object(v) || {}
        source_ids.include?(obj["income_source_id"]) &&
          obj["year"] == year &&
          obj["month"] == month
      }
      .map(&:item_id)

    PaperTrail::Version
      .where(item_type: "IncomeSourceOverride")
      .where(item_id: live_ids + destroyed_ids)
      .includes(:item)
      .order(created_at: :desc)
      .limit(limit)
  end

  def parse_paper_trail_object(version)
    return nil if version.object.blank?

    YAML.safe_load(
      version.object,
      permitted_classes: [ BigDecimal, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Time ],
      aliases: true
    )
  rescue StandardError
    nil
  end
end
