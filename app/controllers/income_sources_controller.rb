# frozen_string_literal: true

class IncomeSourcesController < ApplicationController
  before_action :set_income_source, only: [ :update, :destroy ]
  before_action :authorize_edit, only: [ :update, :destroy ]

  def index
    @my_income_sources = current_user.income_sources.to_a
    @household_income_sources = household_income_sources
    @new_income_source = IncomeSource.new
    @linkable_users = linkable_users
  end

  def create
    @income_source = current_user.income_sources.build(income_source_params)
    @income_source.monthly_budget = current_budget

    if @income_source.save
      redirect_to income_sources_path, notice: "Income source added."
    else
      @my_income_sources = current_user.income_sources.reload.to_a
      @household_income_sources = household_income_sources
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
    @income_source = IncomeSource.find_by(id: params[:id])
    return redirect_to income_sources_path, alert: "Income source not found." unless @income_source
    redirect_to income_sources_path, alert: "Access denied." unless @income_source.accessible_by?(current_user)
  end

  def authorize_edit
    redirect_to income_sources_path, alert: "You cannot edit this income source." unless @income_source.editable_by?(current_user)
  end

  def household_income_sources
    return [] unless current_user.household

    current_user.household.members
      .where.not(id: current_user.id)
      .flat_map { |member| member.income_sources.select { |is| is.accessible_by?(current_user) } }
  end

  def income_source_params
    params.require(:income_source).permit(:name, :amount, :currency, :income_type, :linked_user_id, :active)
  end

  def linkable_users
    users = [ current_user ]
    users += current_user.household.members.to_a if current_user.household
    users.uniq
  end

  def current_budget
    year = Date.current.year
    month = Date.current.month
    current_user.monthly_budgets.find_or_create_by(year: year, month: month)
  end
end
