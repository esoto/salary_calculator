# frozen_string_literal: true

class BudgetItemsController < ApplicationController
  before_action :set_budget
  before_action :authorize_budget_access
  before_action :set_budget_item, only: [ :update, :destroy, :toggle_paid ]

  def create
    @budget_item = @budget.budget_items.build(budget_item_params)

    if @budget_item.save
      respond_to do |format|
        format.html { redirect_to budget_path(@budget), notice: "Item added." }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to budget_path(@budget), alert: @budget_item.errors.full_messages.join(", ") }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("item_form", partial: "budget_items/form", locals: { budget: @budget, budget_item: @budget_item }) }
      end
    end
  end

  def update
    if @budget_item.update(budget_item_params)
      respond_to do |format|
        format.html { redirect_to budget_path(@budget) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to budget_path(@budget), alert: @budget_item.errors.full_messages.join(", ") }
        format.turbo_stream
      end
    end
  end

  def destroy
    @budget_item.destroy
    respond_to do |format|
      format.html { redirect_to budget_path(@budget), notice: "Item removed." }
      format.turbo_stream
    end
  end

  def toggle_paid
    @budget_item.update!(paid: !@budget_item.paid)
    respond_to do |format|
      format.html { redirect_to budget_path(@budget) }
      format.turbo_stream
    end
  end

  private

  def set_budget
    @budget = MonthlyBudget.find(params[:budget_id])
  end

  def set_budget_item
    @budget_item = @budget.budget_items.find(params[:id])
  end

  def budget_item_params
    params.require(:budget_item).permit(:name, :category, :amount, :currency, :paid, :position)
  end

  def authorize_budget_access
    return if @budget.user == current_user
    return if current_user.household&.members&.include?(@budget.user)

    redirect_to budgets_path, alert: "Access denied."
  end
end
