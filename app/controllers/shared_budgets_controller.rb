# frozen_string_literal: true

class SharedBudgetsController < ApplicationController
  skip_before_action :require_authentication

  def show
    @share = BudgetShare.find_by(token: params[:token])

    if @share.nil?
      raise ActiveRecord::RecordNotFound
    elsif @share.expired?
      render :expired
    else
      @budget = @share.monthly_budget
      @income_sources = @budget.user.income_sources.active if @share.show_income_sources
      @salary_entry = @budget.user.salary_entries.find_by(year: @budget.year, month: @budget.month) if @share.show_personal_savings
    end
  end
end
