# frozen_string_literal: true

module BudgetScoped
  extend ActiveSupport::Concern

  private

  def set_budget
    @budget = MonthlyBudget.find(budget_id_param)
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
