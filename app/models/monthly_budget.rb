class MonthlyBudget < ApplicationRecord
  belongs_to :user
  has_many :budget_items, dependent: :destroy

  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :month, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 },
                    uniqueness: { scope: [:user_id, :year] }
  validates :exchange_rate, presence: true,
                            numericality: { greater_than: 0 }

  scope :for_year, ->(year) { where(year: year) }
  scope :ordered, -> { order(year: :desc, month: :desc) }
end
