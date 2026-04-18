require "rails_helper"

RSpec.describe "income source overrides routing", type: :routing do
  it "routes POST /budgets/:budget_id/income_source_overrides" do
    expect(post: "/budgets/1/income_source_overrides")
      .to route_to(controller: "income_source_overrides", action: "create", budget_id: "1")
  end

  it "routes DELETE /budgets/:budget_id/income_source_overrides/:id" do
    expect(delete: "/budgets/1/income_source_overrides/42")
      .to route_to(controller: "income_source_overrides", action: "destroy", budget_id: "1", id: "42")
  end
end
