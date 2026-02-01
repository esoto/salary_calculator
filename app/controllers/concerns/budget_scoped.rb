# frozen_string_literal: true

module BudgetScoped
  extend ActiveSupport::Concern

  private

  # Use for actions where household members may view (e.g., show)
  def set_budget
    @budget = MonthlyBudget.find(budget_id_param)
  end

  # Use for owner-only actions (defense in depth - enforces ownership at query level)
  # TODO: Switch manage actions to use this when implementing owner-only editing
  # See: docs/plans/future/budget-access-control.md
  def set_owned_budget
    @budget = current_user.monthly_budgets.find(budget_id_param)
  end

  def authorize_budget_access
    return if @budget.user == current_user
    return if current_user.household&.members&.include?(@budget.user)

    redirect_to budgets_path, alert: "Access denied."
  end

  def budget_id_param
    params[:budget_id] || params[:id]
  end
end
