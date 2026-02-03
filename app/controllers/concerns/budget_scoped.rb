# frozen_string_literal: true

module BudgetScoped
  extend ActiveSupport::Concern

  private

  def set_budget
    @budget = MonthlyBudget.find(budget_id_param)
  end

  def set_owned_budget
    @budget = current_user.monthly_budgets.find(budget_id_param)
  end

  def authorize_budget_access
    return if @budget.accessible_by?(current_user)

    redirect_to budgets_path, alert: "Access denied."
  end

  def authorize_budget_owner
    return if @budget.owned_by?(current_user)

    redirect_to budgets_path, alert: "Only the owner can do this."
  end

  def budget_id_param
    params[:budget_id] || params[:id]
  end
end
