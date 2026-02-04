# frozen_string_literal: true

class BudgetSharesController < ApplicationController
  include BudgetScoped

  before_action :set_budget
  before_action :set_budget_share, only: [ :destroy ]
  before_action :authorize_budget_owner

  def create
    @share = @budget.budget_shares.build(share_params)

    if @share.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to budget_path(@budget), notice: "Share link created." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("share_form", partial: "budget_shares/form", locals: { budget: @budget, share: @share }) }
        format.html { redirect_to budget_path(@budget), alert: "Could not create share link." }
      end
    end
  end

  def destroy
    @share.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to budget_path(@budget), notice: "Share link revoked." }
    end
  end

  private

  def set_budget_share
    @share = @budget.budget_shares.find(params[:id])
  end

  def share_params
    params.require(:budget_share).permit(:name, :show_budget, :show_income_sources, :show_personal_savings, :expires_at)
  end
end
