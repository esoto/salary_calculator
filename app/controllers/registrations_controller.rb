# frozen_string_literal: true

class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  layout "landing", only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for(@user)
      redirect_to salary_entries_path, notice: "Welcome! Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :name, :default_hourly_rate)
  end
end
