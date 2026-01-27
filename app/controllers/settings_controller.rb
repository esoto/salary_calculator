# frozen_string_literal: true

class SettingsController < ApplicationController
  before_action :set_user_and_household

  def show
  end

  def update
    if @user.update(settings_params)
      redirect_to settings_path, notice: "Settings saved successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user_and_household
    @user = Current.user
    @household = Current.user.household
  end

  def settings_params
    params.require(:user).permit(
      :name,
      :email_address,
      :current_password,
      :password,
      :password_confirmation,
      :vacation_days_per_year,
      :holiday_days_per_year,
      :hours_per_day,
      :aguinaldo_enabled,
      :vacation_enabled,
      :holiday_enabled
    )
  end
end
