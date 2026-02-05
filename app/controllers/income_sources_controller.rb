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
    owner = find_owner_for_income_source
    @income_source = owner.income_sources.build(income_source_params)

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

    # Get ids of members who have shared budgets (avoids N+1 in accessible_by? check)
    sharing_member_ids = current_user.household.members
      .joins(:monthly_budgets)
      .where(monthly_budgets: { shared_with_household: true })
      .where.not(id: current_user.id)
      .distinct
      .pluck(:id)

    return [] if sharing_member_ids.empty?

    # Fetch income sources with eager loading to avoid N+1 in view
    # Include monthly_budgets for editable_by? check in view
    IncomeSource.where(user_id: sharing_member_ids)
      .includes(:linked_user, user: :monthly_budgets)
      .to_a
  end

  def income_source_params
    params.require(:income_source).permit(:name, :amount, :currency, :income_type, :linked_user_id, :active)
  end

  def linkable_users
    users = [ current_user ]
    users += current_user.household.members.to_a if current_user.household
    users.uniq
  end

  def find_owner_for_income_source
    return current_user unless params[:income_source][:user_id].present?

    user_id = params[:income_source][:user_id].to_i
    owner = linkable_users.find { |u| u.id == user_id }
    owner || current_user
  end
end
