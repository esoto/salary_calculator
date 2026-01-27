class HouseholdsController < ApplicationController
  before_action :require_no_household, only: [:create, :join]
  before_action :set_household, only: [:leave, :regenerate_code]
  before_action :require_membership, only: [:leave, :regenerate_code]

  def create
    @household = Household.new(household_params)

    if @household.save
      @household.household_memberships.create!(user: Current.user)
      redirect_to settings_path, notice: "Household created successfully."
    else
      redirect_to settings_path, alert: @household.errors.full_messages.join(", ")
    end
  end

  def join
    household = Household.find_by(invite_code: params[:invite_code]&.upcase)

    if household.nil?
      redirect_to settings_path, alert: "Invalid invite code."
    else
      household.household_memberships.create!(user: Current.user)
      redirect_to settings_path, notice: "You have joined #{household.name}."
    end
  end

  def leave
    @household.household_memberships.find_by(user: Current.user)&.destroy
    @household.destroy if @household.members.empty?
    redirect_to settings_path, notice: "You have left the household."
  end

  def regenerate_code
    @household.regenerate_invite_code!
    redirect_to settings_path, notice: "Invite code regenerated."
  end

  private

  def set_household
    @household = Household.find(params[:id])
  end

  def household_params
    params.require(:household).permit(:name)
  end

  def require_no_household
    if Current.user.household.present?
      redirect_to settings_path, alert: "You are already in a household."
    end
  end

  def require_membership
    unless Current.user.household == @household
      redirect_to settings_path, alert: "You are not a member of this household."
    end
  end
end
