module Api
  module V1
    class MonthlyBudgetsController < Api::BaseController
      before_action -> { require_scope!("budget:read") }

      def current
        today = Date.current
        budget = Current.user.monthly_budgets.find_by(year: today.year, month: today.month)

        return render(json: { error: "not_found" }, status: :not_found) if budget.nil?

        if stale?(last_modified: budget.updated_at, etag: budget.cache_key_with_version, public: false)
          render json: serialize(budget)
        end
      end

      private

      def serialize(budget)
        {
          monthly_budget: {
            id: budget.id,
            year: budget.year,
            month: budget.month,
            exchange_rate: budget.exchange_rate.to_s,
            shared_with_household: budget.shared_with_household.present?,
            updated_at: budget.updated_at.iso8601
          },
          budget_items: budget.budget_items.ordered.map { |item| serialize_item(item) }
        }
      end

      def serialize_item(item)
        {
          id: item.id,
          name: item.name,
          category: item.category,
          amount: item.amount.to_s,
          currency: BudgetItem.currencies[item.currency],
          position: item.position,
          paid: item.paid,
          updated_at: item.updated_at.iso8601
        }
      end
    end
  end
end
