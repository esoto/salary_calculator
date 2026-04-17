class IncomeSourceOverride < ApplicationRecord
  belongs_to :income_source

  has_paper_trail

  enum :scope, { single_month: "single_month", from_this_month: "from_this_month" }, validate: true

  validates :year,  presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :income_source_must_be_fixed

  private

  def income_source_must_be_fixed
    return if income_source.blank? || income_source.fixed?
    errors.add(:income_source, "must be fixed income type to have overrides")
  end
end
