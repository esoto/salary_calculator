class Household < ApplicationRecord
  has_many :household_memberships, dependent: :destroy
  has_many :members, through: :household_memberships, source: :user

  validates :name, presence: true
  validates :invite_code, presence: true, uniqueness: true

  before_validation :generate_invite_code, on: :create

  def regenerate_invite_code!
    update!(invite_code: self.class.generate_unique_code)
  end

  def combined_earnings_for_year(year)
    SalaryEntry.where(user: members).for_year(year).sum { |e| e.monthly_salary }
  end

  def combined_savings_for_year(year)
    entries = SalaryEntry.where(user: members).for_year(year)
    calculate_total_savings(entries)
  end

  def member_stats_for_year(year)
    entries_by_user = SalaryEntry.where(user: members)
                                  .for_year(year)
                                  .group_by(&:user_id)

    members.map do |member|
      entries = entries_by_user[member.id] || []
      earnings = entries.sum { |e| e.monthly_salary }
      savings = calculate_total_savings(entries)
      {
        id: member.id,
        name: member.name,
        earnings: earnings,
        savings: savings
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

  def self.generate_unique_code
    loop do
      code = SecureRandom.alphanumeric(6).upcase
      break code unless exists?(invite_code: code)
    end
  end
end
