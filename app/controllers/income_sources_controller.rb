# frozen_string_literal: true

class IncomeSourcesController < ApplicationController
  before_action :set_income_source, only: [ :update, :destroy ]

  def index
    @income_sources = current_user.income_sources.to_a
    @new_income_source = IncomeSource.new
    @linkable_users = linkable_users
  end

  def create
    @income_source = current_user.income_sources.build(income_source_params)

    if @income_source.save
      redirect_to income_sources_path, notice: "Income source added."
    else
      @income_sources = current_user.income_sources.reload.to_a
      @new_income_source = @income_source
      @linkable_users = linkable_users
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @income_source.update(income_source_params)
      redirect_to income_sources_path, notice: "Income source updated."
    else
      redirect_to income_sources_path, alert: @income_source.errors.full_messages.join(", ")
    end
  end

  def destroy
    @income_source.destroy
    redirect_to income_sources_path, notice: "Income source removed."
  end

  private

  def set_income_source
    @income_source = current_user.income_sources.find_by(id: params[:id])
    redirect_to income_sources_path, alert: "Income source not found." unless @income_source
  end

  def income_source_params
    params.require(:income_source).permit(:name, :amount, :currency, :income_type, :linked_user_id, :active)
  end

  def linkable_users
    users = [ current_user ]
    users += current_user.household.members.to_a if current_user.household
    users.uniq
  end
end
