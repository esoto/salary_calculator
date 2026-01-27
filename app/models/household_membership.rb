class HouseholdMembership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  validates :user_id, uniqueness: { message: 'is already in a household' }

  before_create :set_joined_at

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
