# frozen_string_literal: true

class IncomeSourceOverridesController < ApplicationController
  before_action :set_budget
  before_action :set_income_source,        only: :create
  before_action :set_override_and_source,  only: :destroy
  before_action :authorize!,                only: [ :create, :destroy ]

  def create
    @override = @income_source.income_source_overrides.find_or_initialize_by(
      year:  @budget.year,
      month: @budget.month,
      scope: override_params[:scope]
    )
    @override.amount = override_params[:amount]

    if @override.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to budget_path(@budget), notice: "Income override saved." }
      end
    else
      redirect_to budget_path(@budget), alert: @override.errors.full_messages.to_sentence
    end
  end

  def destroy
    @override.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to budget_path(@budget), notice: "Income override removed." }
    end
  end

  private

  def set_budget
    @budget = MonthlyBudget.find_by(id: params[:budget_id])
    return redirect_to(budgets_path, alert: "Budget not found.") unless @budget
    redirect_to(budgets_path, alert: "Access denied.") unless @budget.accessible_by?(current_user)
  end

  def set_income_source
    return if performed? # earlier before_action already redirected

    @income_source = IncomeSource.find_by(id: override_params[:income_source_id])
    return redirect_to(budget_path(@budget), alert: "Income source not found.") unless @income_source

    # SEC-1 IDOR guard: verify source is actually on this budget
    unless @budget.all_income_sources.any? { |s| s.id == @income_source.id }
      redirect_to(budget_path(@budget), alert: "Income source not on this budget.")
    end
  end

  def set_override_and_source
    return if performed?

    @override = IncomeSourceOverride.find_by(id: params[:id])
    return redirect_to(budget_path(@budget), alert: "Override not found.") unless @override

    @income_source = @override.income_source
    # SEC-1 IDOR guard: verify override's parent source is actually on this budget
    unless @budget.all_income_sources.any? { |s| s.id == @income_source.id }
      redirect_to(budget_path(@budget), alert: "Override not on this budget.")
    end
  end

  def authorize!
    return if performed?

    # SEC-2: must be a fixed source AND editable by current_user (per tightened editable_by?)
    unless @income_source.fixed? && @income_source.editable_by?(current_user)
      redirect_to budget_path(@budget), alert: "You cannot modify this income source."
    end
  end

  def override_params
    # SEC-3: year/month deliberately NOT permitted — always derived from @budget server-side
    params.require(:income_source_override).permit(:income_source_id, :amount, :scope)
  end
end
