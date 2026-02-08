# Undo/Restore from Activity Log — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add undo/restore buttons to the budget activity log so owners can restore deleted items and revert changes.

**Architecture:** A new `BudgetVersionsController` with a single `restore` action handles three cases: restore deleted BudgetItems (rebuilds from PaperTrail `reify`), revert BudgetItem updates, and revert MonthlyBudget updates. The activity log is extracted into a partial with conditional "Undo" buttons. Turbo Stream responses update the affected category column and activity log in-place.

**Tech Stack:** Rails 8, PaperTrail (existing), Turbo Streams (existing patterns), RSpec request specs

**Important Rules:**
- **No Claude co-author references** in commit messages — no `Co-Authored-By` lines
- **Commit after each task** — keep commits small and focused for clean PRs
- **Use `haiku` model** for subagents when executing tasks (fast, cost-effective for well-specified steps)

---

### Task 1: Add helper methods (`version_restorable?`, `restore_confirmation_message`)

**Files:**
- Modify: `app/helpers/budgets_helper.rb`
- Modify: `spec/helpers/budgets_helper_spec.rb`

**Step 1: Write the failing tests**

Add to `spec/helpers/budgets_helper_spec.rb` — inside the outer `RSpec.describe BudgetsHelper` block, after the existing specs:

```ruby
describe "#version_restorable?" do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  it "returns true for destroyed budget items" do
    item = create(:budget_item, monthly_budget: budget)
    item.destroy
    version = PaperTrail::Version.where(item_id: item.id, event: "destroy").last
    expect(helper.version_restorable?(version)).to be true
  end

  it "returns true for updated budget items" do
    item = create(:budget_item, monthly_budget: budget)
    item.update!(amount: 50)
    version = item.versions.where(event: "update").last
    expect(helper.version_restorable?(version)).to be true
  end

  it "returns false for created budget items" do
    item = create(:budget_item, monthly_budget: budget)
    version = item.versions.find_by(event: "create")
    expect(helper.version_restorable?(version)).to be false
  end

  it "returns true for updated monthly budgets" do
    budget.update!(exchange_rate: 510)
    version = budget.versions.where(event: "update").last
    expect(helper.version_restorable?(version)).to be true
  end

  it "returns false for created monthly budgets" do
    version = budget.versions.find_by(event: "create")
    expect(helper.version_restorable?(version)).to be false
  end
end

describe "#restore_confirmation_message" do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  it "returns restore message for destroyed items" do
    item = create(:budget_item, monthly_budget: budget, name: "Netflix")
    item.destroy
    version = PaperTrail::Version.where(item_id: item.id, event: "destroy").last
    expect(helper.restore_confirmation_message(version)).to include("Restore")
    expect(helper.restore_confirmation_message(version)).to include("Netflix")
  end

  it "returns revert message for updated items" do
    item = create(:budget_item, monthly_budget: budget, name: "Netflix")
    item.update!(amount: 50)
    version = item.versions.where(event: "update").last
    expect(helper.restore_confirmation_message(version)).to include("Revert")
    expect(helper.restore_confirmation_message(version)).to include("Netflix")
  end

  it "returns revert message for updated budgets" do
    budget.update!(exchange_rate: 510)
    version = budget.versions.where(event: "update").last
    expect(helper.restore_confirmation_message(version)).to include("Revert")
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/helpers/budgets_helper_spec.rb`
Expected: FAIL — `NoMethodError: undefined method 'version_restorable?'`

**Step 3: Write the implementation**

Add to `app/helpers/budgets_helper.rb` — as public methods (before the existing `private` keyword on line 88):

```ruby
def version_restorable?(version)
  case version.item_type
  when "BudgetItem"
    version.event.in?(%w[destroy update])
  when "MonthlyBudget"
    version.event == "update"
  else
    false
  end
end

def restore_confirmation_message(version)
  case version.event
  when "destroy"
    "Restore \"#{extract_item_name(version)}\"?"
  when "update"
    if version.item_type == "MonthlyBudget"
      "Revert this budget change? The page will reload."
    else
      "Revert changes to \"#{extract_item_name(version)}\"?"
    end
  else
    "Undo this change?"
  end
end
```

Note: `extract_item_name` is already a private method in this helper — it works for both live and destroyed items.

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/helpers/budgets_helper_spec.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add app/helpers/budgets_helper.rb spec/helpers/budgets_helper_spec.rb
git commit -m "feat: add version_restorable? and restore_confirmation_message helpers"
```

---

### Task 2: Add route and controller for restoring versions

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/budget_versions_controller.rb`
- Create: `spec/requests/budget_versions_spec.rb`

**Step 1: Write the failing tests**

Create `spec/requests/budget_versions_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BudgetVersions", type: :request do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "POST /budgets/:budget_id/versions/:id/restore" do
    context "restoring a deleted budget item" do
      let!(:item) { create(:budget_item, monthly_budget: budget, name: "Netflix", category: "fixed", amount: 15.99, currency: "usd") }

      before { item.destroy }

      it "restores the deleted item" do
        version = PaperTrail::Version.where(item_type: "BudgetItem", item_id: item.id, event: "destroy").last

        expect {
          post restore_budget_version_path(budget, version)
        }.to change(BudgetItem, :count).by(1)
      end

      it "restores with correct attributes" do
        version = PaperTrail::Version.where(item_type: "BudgetItem", item_id: item.id, event: "destroy").last
        post restore_budget_version_path(budget, version)

        restored = budget.budget_items.reload.last
        expect(restored.name).to eq("Netflix")
        expect(restored.amount).to eq(15.99)
        expect(restored.category).to eq("fixed")
        expect(restored.currency).to eq("usd")
      end

      it "redirects with a success notice" do
        version = PaperTrail::Version.where(item_type: "BudgetItem", item_id: item.id, event: "destroy").last
        post restore_budget_version_path(budget, version)

        expect(response).to redirect_to(budget_path(budget))
        follow_redirect!
        expect(response.body).to include("restored")
      end
    end

    context "reverting a budget item update" do
      let!(:item) { create(:budget_item, monthly_budget: budget, name: "Netflix", amount: 15.99) }

      before { item.update!(amount: 20.00) }

      it "reverts the item to its previous state" do
        version = item.versions.where(event: "update").last
        post restore_budget_version_path(budget, version)

        expect(item.reload.amount).to eq(15.99)
      end

      it "redirects with a success notice" do
        version = item.versions.where(event: "update").last
        post restore_budget_version_path(budget, version)

        expect(response).to redirect_to(budget_path(budget))
        follow_redirect!
        expect(response.body).to include("reverted")
      end
    end

    context "reverting a monthly budget update" do
      before { budget.update!(exchange_rate: 510) }

      it "reverts the exchange rate" do
        version = budget.versions.where(event: "update").last
        post restore_budget_version_path(budget, version)

        expect(budget.reload.exchange_rate).to eq(503)
      end

      it "redirects with a success notice" do
        version = budget.versions.where(event: "update").last
        post restore_budget_version_path(budget, version)

        expect(response).to redirect_to(budget_path(budget))
        follow_redirect!
        expect(response.body).to include("reverted")
      end
    end

    context "when item no longer exists (update version for deleted item)" do
      let!(:item) { create(:budget_item, monthly_budget: budget, name: "Test") }

      before do
        item.update!(amount: 50)
        item.destroy
      end

      it "returns error for update version of destroyed item" do
        update_version = item.versions.where(event: "update").last
        post restore_budget_version_path(budget, update_version)

        expect(response).to redirect_to(budget_path(budget))
        follow_redirect!
        expect(response.body).to include("no longer exists")
      end
    end

    context "with non-restorable version events" do
      it "rejects create events for budget items" do
        item = create(:budget_item, monthly_budget: budget)
        version = item.versions.find_by(event: "create")
        post restore_budget_version_path(budget, version)

        expect(response).to redirect_to(budget_path(budget))
        follow_redirect!
        expect(response.body).to include("Cannot")
      end

      it "rejects create events for budgets" do
        version = budget.versions.find_by(event: "create")
        post restore_budget_version_path(budget, version)

        expect(response).to redirect_to(budget_path(budget))
        follow_redirect!
        expect(response.body).to include("Cannot")
      end
    end

    context "access control" do
      let(:other_user) { create(:user) }
      let(:other_budget) { create(:monthly_budget, user: other_user) }
      let!(:other_item) { create(:budget_item, monthly_budget: other_budget, name: "Item") }

      it "denies non-owner access" do
        other_item.destroy
        version = PaperTrail::Version.where(item_type: "BudgetItem", item_id: other_item.id, event: "destroy").last
        post restore_budget_version_path(other_budget, version)

        expect(response).to redirect_to(budgets_path)
      end
    end

    context "version belongs to different budget" do
      let(:other_budget) { create(:monthly_budget, user: user) }
      let!(:other_item) { create(:budget_item, monthly_budget: other_budget, name: "Other") }

      it "rejects versions from a different budget" do
        other_item.destroy
        version = PaperTrail::Version.where(item_type: "BudgetItem", item_id: other_item.id, event: "destroy").last

        post restore_budget_version_path(budget, version)
        expect(response).to redirect_to(budget_path(budget))
        follow_redirect!
        expect(response.body).to include("not found")
      end
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/budget_versions_spec.rb`
Expected: FAIL — routing error (no route matches)

**Step 3: Add the route**

In `config/routes.rb`, add inside the `resources :budgets` block (after `budget_shares`):

```ruby
resources :versions, only: [], controller: "budget_versions" do
  member do
    post :restore
  end
end
```

The full block becomes:
```ruby
resources :budgets, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
  resources :budget_items, only: [ :create, :update, :destroy ] do
    member do
      patch :toggle_paid
    end
  end
  resources :budget_shares, only: [ :create, :destroy ]
  resources :versions, only: [], controller: "budget_versions" do
    member do
      post :restore
    end
  end
end
```

This creates: `POST /budgets/:budget_id/versions/:id/restore` → `budget_versions#restore`

**Step 4: Create the controller**

Create `app/controllers/budget_versions_controller.rb`:

```ruby
# frozen_string_literal: true

class BudgetVersionsController < ApplicationController
  include BudgetScoped

  before_action :set_budget
  before_action :authorize_budget_owner
  before_action :set_version

  def restore
    result = restore_version

    if result[:success]
      redirect_to budget_path(@budget), notice: result[:message]
    else
      redirect_to budget_path(@budget), alert: result[:message]
    end
  end

  private

  def set_version
    @version = PaperTrail::Version.find(params[:id])
    unless version_belongs_to_budget?
      redirect_to budget_path(@budget), alert: "Version not found."
    end
  end

  def version_belongs_to_budget?
    case @version.item_type
    when "MonthlyBudget"
      @version.item_id == @budget.id
    when "BudgetItem"
      if @version.event == "destroy"
        @version.reify&.monthly_budget_id == @budget.id
      else
        @budget.budget_items.exists?(@version.item_id)
      end
    else
      false
    end
  end

  def restore_version
    case @version.item_type
    when "BudgetItem"
      restore_budget_item
    when "MonthlyBudget"
      restore_monthly_budget
    else
      { success: false, message: "Cannot restore this type of change." }
    end
  end

  def restore_budget_item
    case @version.event
    when "destroy"
      restore_deleted_item
    when "update"
      revert_item_update
    else
      { success: false, message: "Cannot undo this type of change." }
    end
  end

  def restore_deleted_item
    reified = @version.reify
    return { success: false, message: "Cannot restore: version data is missing." } unless reified

    restored = @budget.budget_items.build(
      reified.attributes.slice("name", "category", "amount", "currency", "paid", "position")
    )

    if restored.save
      { success: true, message: "\"#{restored.name}\" has been restored." }
    else
      { success: false, message: "Could not restore item: #{restored.errors.full_messages.join(', ')}" }
    end
  end

  def revert_item_update
    item = @version.item
    return { success: false, message: "Item no longer exists." } unless item

    reified = @version.reify
    return { success: false, message: "Cannot restore: version data is missing." } unless reified

    revertable_attrs = reified.attributes.slice("name", "amount", "currency", "paid", "position")

    if item.update(revertable_attrs)
      { success: true, message: "\"#{item.name}\" has been reverted." }
    else
      { success: false, message: "Could not revert: #{item.errors.full_messages.join(', ')}" }
    end
  end

  def restore_monthly_budget
    return { success: false, message: "Cannot undo this type of change." } unless @version.event == "update"

    reified = @version.reify
    return { success: false, message: "Cannot restore: version data is missing." } unless reified

    revertable_attrs = reified.attributes.slice("exchange_rate", "shared_with_household")

    if @budget.update(revertable_attrs)
      { success: true, message: "Budget settings have been reverted." }
    else
      { success: false, message: "Could not revert: #{@budget.errors.full_messages.join(', ')}" }
    end
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/budget_versions_spec.rb`
Expected: All PASS

**Step 6: Commit**

```bash
git add config/routes.rb app/controllers/budget_versions_controller.rb spec/requests/budget_versions_spec.rb
git commit -m "feat: add restore endpoint for budget activity log versions"
```

---

### Task 3: Extract activity log into partial with Undo buttons

**Files:**
- Create: `app/views/budgets/_activity_log.html.erb`
- Modify: `app/views/budgets/show.html.erb` (lines 132-151)

**Step 1: Create the partial**

Create `app/views/budgets/_activity_log.html.erb`:

```erb
<% activity = budget.recent_activity(limit: 10) %>
<% if activity.any? %>
  <div id="activity-log">
    <details class="bg-white rounded-lg shadow mt-6">
      <summary class="cursor-pointer px-4 py-3 text-lg font-semibold text-gray-800 hover:bg-gray-50 rounded-t-lg">
        Recent Activity
      </summary>
      <div class="px-4 pb-4">
        <ul class="divide-y divide-gray-100">
          <% activity.each do |version| %>
            <li class="py-2 text-sm flex items-center justify-between gap-2">
              <div>
                <span class="font-medium"><%= activity_actor_name(version, current_user) %></span>
                <span class="text-gray-600"><%= activity_description(version) %></span>
                <span class="text-gray-400 text-xs ml-2"><%= activity_time_ago(version) %></span>
              </div>
              <% if budget.owned_by?(current_user) && version_restorable?(version) %>
                <%= button_to "Undo",
                    restore_budget_version_path(budget, version),
                    method: :post,
                    data: { turbo_confirm: restore_confirmation_message(version) },
                    class: "text-blue-600 hover:text-blue-800 text-xs font-medium shrink-0" %>
              <% end %>
            </li>
          <% end %>
        </ul>
      </div>
    </details>
  </div>
<% end %>
```

**Step 2: Replace inline activity log in show.html.erb**

In `app/views/budgets/show.html.erb`, replace lines 132-151 (the `<!-- Activity Log Section -->` block through the closing `<% end %>`) with:

```erb
  <%= render "budgets/activity_log", budget: @budget %>
```

**Step 3: Run existing tests to verify no regressions**

Run: `bundle exec rspec spec/requests/budgets_spec.rb`
Expected: All PASS (activity log still renders)

**Step 4: Commit**

```bash
git add app/views/budgets/_activity_log.html.erb app/views/budgets/show.html.erb
git commit -m "refactor: extract activity log into partial with undo buttons"
```

---

### Task 4: Add Turbo Stream response for restore

**Files:**
- Create: `app/views/budget_versions/restore.turbo_stream.erb`
- Modify: `app/controllers/budget_versions_controller.rb` (add turbo_stream format)

**Step 1: Update controller to support turbo_stream**

In `app/controllers/budget_versions_controller.rb`, change the `restore` method to:

```ruby
def restore
  result = restore_version

  if result[:success]
    respond_to do |format|
      format.html { redirect_to budget_path(@budget), notice: result[:message] }
      format.turbo_stream { @category = result[:category] }
    end
  else
    redirect_to budget_path(@budget), alert: result[:message]
  end
end
```

Also update `restore_deleted_item` and `revert_item_update` to include `:category` in their return hashes:

In `restore_deleted_item`, change the success return to:
```ruby
{ success: true, message: "\"#{restored.name}\" has been restored.", category: restored.category }
```

In `revert_item_update`, change the success return to:
```ruby
{ success: true, message: "\"#{item.name}\" has been reverted.", category: item.category }
```

`restore_monthly_budget` does NOT need a category — it will always use the HTML redirect (page reload), since exchange rate changes affect all amounts on the page.

**Step 2: Create the Turbo Stream template**

Create `app/views/budget_versions/restore.turbo_stream.erb`:

```erb
<% @budget.budget_items.reload %>

<%= turbo_stream.replace dom_id(@budget, @category) do %>
  <%= render "budgets/category_column", budget: @budget, category: @category %>
<% end %>

<%= turbo_stream.replace "activity-log" do %>
  <%# Re-render just the inner content of the activity-log div %>
  <% activity = @budget.recent_activity(limit: 10) %>
  <% if activity.any? %>
    <div id="activity-log">
      <details class="bg-white rounded-lg shadow mt-6" open>
        <summary class="cursor-pointer px-4 py-3 text-lg font-semibold text-gray-800 hover:bg-gray-50 rounded-t-lg">
          Recent Activity
        </summary>
        <div class="px-4 pb-4">
          <ul class="divide-y divide-gray-100">
            <% activity.each do |version| %>
              <li class="py-2 text-sm flex items-center justify-between gap-2">
                <div>
                  <span class="font-medium"><%= activity_actor_name(version, current_user) %></span>
                  <span class="text-gray-600"><%= activity_description(version) %></span>
                  <span class="text-gray-400 text-xs ml-2"><%= activity_time_ago(version) %></span>
                </div>
                <% if @budget.owned_by?(current_user) && version_restorable?(version) %>
                  <%= button_to "Undo",
                      restore_budget_version_path(@budget, version),
                      method: :post,
                      data: { turbo_confirm: restore_confirmation_message(version) },
                      class: "text-blue-600 hover:text-blue-800 text-xs font-medium shrink-0" %>
                <% end %>
              </li>
            <% end %>
          </ul>
        </div>
      </details>
    </div>
  <% end %>
<% end %>
```

Note: The turbo_stream response uses `open` on `<details>` so the activity log stays expanded after the undo (the user was already looking at it). The partial can't be reused directly here because the turbo_stream `replace` needs the outer `<div id="activity-log">` wrapper to be the replaced content.

**Step 3: Run all tests**

Run: `bundle exec rspec spec/requests/budget_versions_spec.rb spec/requests/budgets_spec.rb`
Expected: All PASS

**Step 4: Commit**

```bash
git add app/controllers/budget_versions_controller.rb app/views/budget_versions/restore.turbo_stream.erb
git commit -m "feat: add turbo stream response for version restore"
```

---

### Task 5: Run full test suite and verify

**Step 1: Run full test suite**

Run: `bundle exec rspec`
Expected: All 553+ tests PASS, no regressions

**Step 2: Manual verification**

1. Visit a budget page, add an item, delete it
2. Expand "Recent Activity" — see "Undo" button next to "removed ..." entry
3. Click "Undo" — confirm dialog appears
4. Confirm — item reappears in the category column, activity log updates
5. Edit an item's amount, then click "Undo" next to the update entry — amount reverts
6. Change exchange rate, click "Undo" — page reloads with old rate
7. Verify "Undo" does NOT appear next to "created" or "added" entries

**Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "feat: undo/restore from activity log"
```

---

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `app/helpers/budgets_helper.rb` | Modify | Add `version_restorable?` and `restore_confirmation_message` |
| `config/routes.rb` | Modify | Add `POST budgets/:id/versions/:id/restore` |
| `app/controllers/budget_versions_controller.rb` | Create | Restore logic with authorization |
| `app/views/budgets/_activity_log.html.erb` | Create | Extracted partial with Undo buttons |
| `app/views/budgets/show.html.erb` | Modify | Replace inline activity log with partial |
| `app/views/budget_versions/restore.turbo_stream.erb` | Create | Turbo Stream response |
| `spec/helpers/budgets_helper_spec.rb` | Modify | Tests for new helpers |
| `spec/requests/budget_versions_spec.rb` | Create | Request specs for restore |

## Scope Boundaries

**In scope:** Restore deleted BudgetItems, revert BudgetItem updates, revert MonthlyBudget updates (exchange_rate, shared_with_household)

**Out of scope:** Restoring deleted budgets (cascade complexity), undoing creates (user can just delete), time-based restrictions, batch undo

**No new migrations needed** — uses existing PaperTrail `versions` table as-is.
