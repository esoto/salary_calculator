class Household < ApplicationRecord
  has_many :household_memberships, dependent: :destroy
  has_many :members, through: :household_memberships, source: :user

  validates :name, presence: true
  validates :invite_code, presence: true, uniqueness: true

  before_validation :generate_invite_code, on: :create

  def regenerate_invite_code!
    regenerate_invite_code
    save!
  end

  def combined_earnings_for_year(year)
    SalaryEntry.where(user: members).for_year(year).sum("hours_worked * hourly_rate")
  end

  def combined_savings_for_year(year)
    entries = SalaryEntry.where(user: members).for_year(year)
    calculate_total_savings(entries)
  end

  def member_stats_for_year(year)
    # Get earnings per user via SQL aggregation
    earnings_by_user = SalaryEntry.where(user: members)
                                   .for_year(year)
                                   .group(:user_id)
                                   .sum("hours_worked * hourly_rate")

    # Savings require Ruby calculation (computed methods depend on user settings)
    entries_by_user = SalaryEntry.where(user: members)
                                  .for_year(year)
                                  .group_by(&:user_id)

    members.map do |member|
      entries = entries_by_user[member.id] || []
      {
        id: member.id,
        name: member.name,
        earnings: earnings_by_user[member.id] || 0,
        savings: calculate_total_savings(entries)
      }
    end
  end

  private

  def calculate_total_savings(entries)
    entries.sum { |e| e.aguinaldo_savings + e.vacation_savings + e.holiday_savings }
  end

  def generate_invite_code
    self.invite_code ||= self.class.generate_unique_code
  end

  def regenerate_invite_code
    self.invite_code = self.class.generate_unique_code
  end

  def self.generate_unique_code
    10.times do
      code = SecureRandom.alphanumeric(6).upcase
      return code unless exists?(invite_code: code)
    end
    raise ActiveRecord::RecordNotUnique, "Failed to generate unique invite code after 10 attempts"
  end
end
