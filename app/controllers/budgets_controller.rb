# frozen_string_literal: true

class BudgetsController < ApplicationController
  include BudgetScoped

  before_action :set_budget, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_budget_access, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_budget_owner, only: [:destroy]

  def index
    @year = params[:year]&.to_i || Date.current.year
    @my_budgets = current_user.monthly_budgets
      .for_year(@year)
      .ordered
      .includes(:budget_items, user: { income_sources: { linked_user: :salary_entries } })

    @household_budgets = []
    if current_user.household
      @household_budgets = MonthlyBudget
        .where(user: current_user.household.members.where.not(id: current_user.id))
        .for_year(@year)
        .ordered
        .includes(:budget_items, user: { income_sources: { linked_user: :salary_entries } })
    end
  end

  def show
    @income_sources = @budget.user.income_sources.active
  end

  def new
    @budget = current_user.monthly_budgets.build(
      year: params[:year] || Date.current.year,
      month: params[:month] || Date.current.month,
      exchange_rate: MonthlyBudget::DEFAULT_EXCHANGE_RATE
    )
  end

  def create
    @budget = current_user.monthly_budgets.build(budget_params)

    if @budget.save
      @budget.copy_items_from(previous_budget) if previous_budget
      redirect_to budget_path(@budget), notice: "Budget created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @budget.update(budget_params)
      redirect_to budget_path(@budget), notice: "Budget updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @budget.destroy
    redirect_to budgets_path, notice: "Budget deleted."
  end

  private

  def budget_params
    params.require(:monthly_budget).permit(:year, :month, :exchange_rate, :shared_with_household)
  end

  def previous_budget
    @previous_budget ||= current_user.monthly_budgets
      .where("(year = ? AND month < ?) OR year < ?", @budget.year, @budget.month, @budget.year)
      .order(year: :desc, month: :desc)
      .first
  end
end
