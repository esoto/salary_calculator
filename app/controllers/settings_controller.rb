# frozen_string_literal: true

class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(settings_params)
      redirect_to settings_path, notice: "Settings saved successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

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
