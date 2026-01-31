class HouseholdsController < ApplicationController
  before_action :require_no_household, only: [ :create, :join ]
  before_action :set_household, only: [ :leave, :regenerate_code ]
  before_action :require_membership, only: [ :leave, :regenerate_code ]

  def create
    @household = Household.new(household_params)

    if @household.save
      membership = @household.household_memberships.create(user: current_user)
      if membership.persisted?
        redirect_to settings_path, notice: "Household created successfully."
      else
        @household.destroy
        redirect_to settings_path, alert: "You are already in a household."
      end
    else
      redirect_to settings_path, alert: @household.errors.full_messages.join(", ")
    end
  end

  def join
    household = Household.find_by(invite_code: params[:invite_code]&.upcase)

    if household.nil?
      redirect_to settings_path, alert: "Invalid invite code."
    else
      membership = household.household_memberships.create(user: current_user)
      if membership.persisted?
        redirect_to settings_path, notice: "You have joined #{household.name}."
      else
        redirect_to settings_path, alert: "You are already in a household."
      end
    end
  end

  def leave
    @household.transaction do
      @household.household_memberships.find_by(user: current_user)&.destroy
      @household.destroy if @household.household_memberships.count.zero?
    end
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
    if current_user.household.present?
      redirect_to settings_path, alert: "You are already in a household."
    end
  end

  def require_membership
    unless current_user.household == @household
      redirect_to settings_path, alert: "You are not a member of this household."
    end
  end
end
