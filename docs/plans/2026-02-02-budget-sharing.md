# Budget Sharing & Activity Tracking Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add explicit budget sharing with household members and track all changes with PaperTrail for accountability.

**Architecture:** Add `shared_with_household` boolean to MonthlyBudget, integrate PaperTrail for audit trail, update authorization to check sharing status, add UI for toggling sharing and viewing activity.

**Tech Stack:** Rails 8.1, PaperTrail gem, TailwindCSS, Turbo

> ⚠️ **IMPORTANT:** Do NOT include "Co-Authored-By: Claude" or any Claude reference in commit messages.

---

## Task 1: Add PaperTrail Gem

**Files:**
- Modify: `Gemfile`
- Create: `db/migrate/*_create_versions.rb`

**Step 1: Add gem to Gemfile**

Add after the `bcrypt` gem:

```ruby
# Audit trail for tracking changes
gem "paper_trail"
```

**Step 2: Install and generate migration**

Run:
```bash
bundle install
bundle exec rails generate paper_trail:install
```

**Step 3: Run migration**

Run:
```bash
bundle exec rails db:migrate
```

**Step 4: Commit**

```bash
git add Gemfile Gemfile.lock db/migrate/*_create_versions.rb db/schema.rb
git commit -m "chore: add paper_trail gem for audit tracking"
```

---

## Task 2: Add shared_with_household Column

**Files:**
- Create: `db/migrate/*_add_shared_with_household_to_monthly_budgets.rb`

**Step 1: Generate migration**

Run:
```bash
bundle exec rails generate migration AddSharedWithHouseholdToMonthlyBudgets shared_with_household:boolean
```

**Step 2: Edit migration for default value**

Modify the generated migration:

```ruby
class AddSharedWithHouseholdToMonthlyBudgets < ActiveRecord::Migration[8.0]
  def change
    add_column :monthly_budgets, :shared_with_household, :boolean, default: false, null: false
  end
end
```

**Step 3: Run migration**

Run:
```bash
bundle exec rails db:migrate
```

**Step 4: Commit**

```bash
git add db/migrate/*_add_shared_with_household_to_monthly_budgets.rb db/schema.rb
git commit -m "feat: add shared_with_household column to monthly_budgets"
```

---

## Task 3: Add PaperTrail to Models

**Files:**
- Modify: `app/models/monthly_budget.rb`
- Modify: `app/models/budget_item.rb`
- Test: `spec/models/monthly_budget_spec.rb`
- Test: `spec/models/budget_item_spec.rb`

**Step 1: Write failing test for MonthlyBudget versioning**

Add to `spec/models/monthly_budget_spec.rb`:

```ruby
describe "versioning" do
  it "tracks changes with PaperTrail" do
    budget = create(:monthly_budget)
    expect(budget).to be_versioned
  end

  it "records who made changes" do
    user = create(:user)
    PaperTrail.request.whodunnit = user.id
    budget = create(:monthly_budget, exchange_rate: 500)
    budget.update!(exchange_rate: 510)

    expect(budget.versions.last.whodunnit).to eq(user.id.to_s)
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/models/monthly_budget_spec.rb -e "versioning"
```
Expected: FAIL with "undefined method `be_versioned'"

**Step 3: Add PaperTrail to MonthlyBudget**

Add to `app/models/monthly_budget.rb` after the class declaration:

```ruby
has_paper_trail
```

**Step 4: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/models/monthly_budget_spec.rb -e "versioning"
```
Expected: PASS

**Step 5: Write failing test for BudgetItem versioning**

Add to `spec/models/budget_item_spec.rb`:

```ruby
describe "versioning" do
  it "tracks changes with PaperTrail" do
    item = create(:budget_item)
    expect(item).to be_versioned
  end
end
```

**Step 6: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/models/budget_item_spec.rb -e "versioning"
```
Expected: FAIL

**Step 7: Add PaperTrail to BudgetItem**

Add to `app/models/budget_item.rb` after the class declaration:

```ruby
has_paper_trail
```

**Step 8: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/models/budget_item_spec.rb -e "versioning"
```
Expected: PASS

**Step 9: Commit**

```bash
git add app/models/monthly_budget.rb app/models/budget_item.rb spec/models/monthly_budget_spec.rb spec/models/budget_item_spec.rb
git commit -m "feat: add PaperTrail versioning to MonthlyBudget and BudgetItem"
```

---

## Task 4: Add Ownership and Access Methods to MonthlyBudget

**Files:**
- Modify: `app/models/monthly_budget.rb`
- Test: `spec/models/monthly_budget_spec.rb`

**Step 1: Write failing tests for ownership methods**

Add to `spec/models/monthly_budget_spec.rb`:

```ruby
describe "ownership and access" do
  let(:owner) { create(:user) }
  let(:partner) { create(:user) }
  let(:stranger) { create(:user) }
  let(:household) { create(:household) }
  let(:budget) { create(:monthly_budget, user: owner) }

  before do
    create(:household_membership, household: household, user: owner)
    create(:household_membership, household: household, user: partner)
  end

  describe "#owned_by?" do
    it "returns true for the owner" do
      expect(budget.owned_by?(owner)).to be true
    end

    it "returns false for non-owners" do
      expect(budget.owned_by?(partner)).to be false
      expect(budget.owned_by?(stranger)).to be false
    end
  end

  describe "#accessible_by?" do
    context "when not shared" do
      it "returns true for owner" do
        expect(budget.accessible_by?(owner)).to be true
      end

      it "returns false for household members" do
        expect(budget.accessible_by?(partner)).to be false
      end

      it "returns false for strangers" do
        expect(budget.accessible_by?(stranger)).to be false
      end
    end

    context "when shared with household" do
      before { budget.update!(shared_with_household: true) }

      it "returns true for owner" do
        expect(budget.accessible_by?(owner)).to be true
      end

      it "returns true for household members" do
        expect(budget.accessible_by?(partner)).to be true
      end

      it "returns false for strangers" do
        expect(budget.accessible_by?(stranger)).to be false
      end
    end
  end

  describe "#editable_by?" do
    it "follows same rules as accessible_by?" do
      expect(budget.editable_by?(owner)).to be true
      expect(budget.editable_by?(partner)).to be false

      budget.update!(shared_with_household: true)
      expect(budget.editable_by?(partner)).to be true
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run:
```bash
bundle exec rspec spec/models/monthly_budget_spec.rb -e "ownership and access"
```
Expected: FAIL with "undefined method `owned_by?'"

**Step 3: Implement ownership and access methods**

Add to `app/models/monthly_budget.rb`:

```ruby
def owned_by?(check_user)
  user_id == check_user.id
end

def accessible_by?(check_user)
  return true if owned_by?(check_user)
  return false unless shared_with_household?

  check_user.shares_household_with?(user)
end

def editable_by?(check_user)
  accessible_by?(check_user)
end
```

**Step 4: Run tests to verify they pass**

Run:
```bash
bundle exec rspec spec/models/monthly_budget_spec.rb -e "ownership and access"
```
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/monthly_budget.rb spec/models/monthly_budget_spec.rb
git commit -m "feat: add ownership and access control methods to MonthlyBudget"
```

---

## Task 5: Update Authorization in BudgetScoped Concern

**Files:**
- Modify: `app/controllers/concerns/budget_scoped.rb`
- Test: `spec/requests/budgets_spec.rb`

**Step 1: Write failing test for access control**

Add to `spec/requests/budgets_spec.rb` in a new describe block:

```ruby
describe "access control with sharing" do
  let(:household) { create(:household) }
  let(:owner) { create(:user) }
  let(:partner) { create(:user) }
  let(:stranger) { create(:user) }

  before do
    create(:household_membership, household: household, user: owner)
    create(:household_membership, household: household, user: partner)
  end

  describe "private budget" do
    let!(:budget) { create(:monthly_budget, user: owner, shared_with_household: false) }

    it "allows owner to view" do
      sign_in(owner)
      get budget_path(budget)
      expect(response).to have_http_status(:success)
    end

    it "denies household member access" do
      sign_in(partner)
      get budget_path(budget)
      expect(response).to redirect_to(budgets_path)
    end

    it "denies stranger access" do
      sign_in(stranger)
      get budget_path(budget)
      expect(response).to redirect_to(budgets_path)
    end
  end

  describe "shared budget" do
    let!(:budget) { create(:monthly_budget, user: owner, shared_with_household: true) }

    it "allows owner to view" do
      sign_in(owner)
      get budget_path(budget)
      expect(response).to have_http_status(:success)
    end

    it "allows household member to view" do
      sign_in(partner)
      get budget_path(budget)
      expect(response).to have_http_status(:success)
    end

    it "denies stranger access" do
      sign_in(stranger)
      get budget_path(budget)
      expect(response).to redirect_to(budgets_path)
    end
  end

  describe "delete protection" do
    let!(:budget) { create(:monthly_budget, user: owner, shared_with_household: true) }

    it "allows owner to delete" do
      sign_in(owner)
      delete budget_path(budget)
      expect(response).to redirect_to(budgets_path)
      expect(MonthlyBudget.exists?(budget.id)).to be false
    end

    it "denies household member from deleting" do
      sign_in(partner)
      delete budget_path(budget)
      expect(response).to redirect_to(budgets_path)
      expect(MonthlyBudget.exists?(budget.id)).to be true
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run:
```bash
bundle exec rspec spec/requests/budgets_spec.rb -e "access control with sharing"
```
Expected: Some tests FAIL (household member currently has access)

**Step 3: Update BudgetScoped concern**

Replace the content of `app/controllers/concerns/budget_scoped.rb`:

```ruby
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
```

**Step 4: Update BudgetsController to use owner authorization for destroy**

Add to `app/controllers/budgets_controller.rb` after the existing `before_action` lines:

```ruby
before_action :authorize_budget_owner, only: [:destroy]
```

**Step 5: Run tests to verify they pass**

Run:
```bash
bundle exec rspec spec/requests/budgets_spec.rb -e "access control with sharing"
```
Expected: PASS

**Step 6: Commit**

```bash
git add app/controllers/concerns/budget_scoped.rb app/controllers/budgets_controller.rb spec/requests/budgets_spec.rb
git commit -m "feat: update authorization to respect sharing settings"
```

---

## Task 6: Add Sharing Toggle to Budget Edit Form

**Files:**
- Modify: `app/views/budgets/edit.html.erb`
- Modify: `app/controllers/budgets_controller.rb`
- Test: `spec/requests/budgets_spec.rb`

**Step 1: Write failing test for sharing toggle**

Add to `spec/requests/budgets_spec.rb`:

```ruby
describe "sharing toggle" do
  let(:household) { create(:household) }
  let(:user) { create(:user) }
  let!(:budget) { create(:monthly_budget, user: user, shared_with_household: false) }

  before do
    create(:household_membership, household: household, user: user)
    sign_in(user)
  end

  it "allows owner to enable sharing" do
    patch budget_path(budget), params: { monthly_budget: { shared_with_household: true } }
    expect(budget.reload.shared_with_household).to be true
  end

  it "allows owner to disable sharing" do
    budget.update!(shared_with_household: true)
    patch budget_path(budget), params: { monthly_budget: { shared_with_household: false } }
    expect(budget.reload.shared_with_household).to be false
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/requests/budgets_spec.rb -e "sharing toggle"
```
Expected: FAIL (param not permitted)

**Step 3: Add shared_with_household to permitted params**

In `app/controllers/budgets_controller.rb`, update the `budget_params` method:

```ruby
def budget_params
  params.require(:monthly_budget).permit(:year, :month, :exchange_rate, :shared_with_household)
end
```

**Step 4: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/requests/budgets_spec.rb -e "sharing toggle"
```
Expected: PASS

**Step 5: Add sharing checkbox to edit form**

In `app/views/budgets/edit.html.erb`, add after the exchange_rate field (before the submit button):

```erb
<% if current_user.household.present? %>
  <div class="mt-4 pt-4 border-t border-gray-200">
    <label class="flex items-center gap-3 cursor-pointer">
      <%= form.check_box :shared_with_household, class: "w-5 h-5 text-blue-600 rounded focus:ring-blue-500" %>
      <div>
        <span class="font-medium text-gray-700">Share with household</span>
        <p class="text-sm text-gray-500">Household members can view and edit this budget</p>
      </div>
    </label>
  </div>
<% end %>
```

**Step 6: Commit**

```bash
git add app/controllers/budgets_controller.rb app/views/budgets/edit.html.erb spec/requests/budgets_spec.rb
git commit -m "feat: add sharing toggle to budget edit form"
```

---

## Task 7: Show Shared Badge and Owner Name

**Files:**
- Modify: `app/views/budgets/show.html.erb`
- Modify: `app/helpers/budgets_helper.rb`
- Test: `spec/system/budgets_spec.rb`

**Step 1: Write failing system test**

Add to `spec/system/budgets_spec.rb` in the "household sharing" describe block:

```ruby
it "shows shared badge and owner name when viewing shared budget" do
  partner_budget = create(:monthly_budget, user: partner, year: 2026, month: 3, shared_with_household: true)

  visit budget_path(partner_budget)

  expect(page).to have_content("Shared")
  expect(page).to have_content("#{partner.name}'s Budget")
end

it "does not show shared badge on own budget" do
  own_budget = create(:monthly_budget, user: user, year: 2026, month: 4)

  visit budget_path(own_budget)

  expect(page).not_to have_content("Shared")
  expect(page).not_to have_content("#{user.name}'s Budget")
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/system/budgets_spec.rb -e "shows shared badge"
```
Expected: FAIL

**Step 3: Add helper method**

Add to `app/helpers/budgets_helper.rb`:

```ruby
def budget_owner_label(budget)
  return nil if budget.owned_by?(current_user)

  "#{budget.user.name}'s Budget"
end

def budget_shared_badge
  content_tag(:span, "🏠 Shared", class: "text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded")
end
```

**Step 4: Update show view header**

In `app/views/budgets/show.html.erb`, update the header section to show sharing info:

Find the existing header (likely showing month/year) and update it:

```erb
<div class="flex justify-between items-start mb-6">
  <div>
    <div class="flex items-center gap-3">
      <h1 class="text-2xl font-bold text-gray-800">
        <%= Date::MONTHNAMES[@budget.month] %> <%= @budget.year %>
      </h1>
      <% if @budget.shared_with_household? && !@budget.owned_by?(current_user) %>
        <%= budget_shared_badge %>
      <% end %>
    </div>
    <% if owner_label = budget_owner_label(@budget) %>
      <p class="text-gray-600"><%= owner_label %></p>
    <% end %>
  </div>
  <!-- existing buttons/links -->
</div>
```

**Step 5: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/system/budgets_spec.rb -e "shows shared badge"
```
Expected: PASS

**Step 6: Commit**

```bash
git add app/views/budgets/show.html.erb app/helpers/budgets_helper.rb spec/system/budgets_spec.rb
git commit -m "feat: show shared badge and owner name on budget show page"
```

---

## Task 8: Set PaperTrail Whodunnit in ApplicationController

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Test: `spec/requests/budget_items_spec.rb`

**Step 1: Write failing test**

Add to `spec/requests/budget_items_spec.rb`:

```ruby
describe "activity tracking" do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  before { sign_in(user) }

  it "records who created a budget item" do
    post budget_budget_items_path(budget), params: {
      budget_item: { name: "Test", amount: 100, currency: "USD", category: "fixed" }
    }

    item = BudgetItem.last
    expect(item.versions.last.whodunnit).to eq(user.id.to_s)
  end

  it "records who updated a budget item" do
    item = create(:budget_item, monthly_budget: budget)

    patch budget_budget_item_path(budget, item), params: {
      budget_item: { amount: 200 }
    }

    expect(item.versions.last.whodunnit).to eq(user.id.to_s)
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/requests/budget_items_spec.rb -e "activity tracking"
```
Expected: FAIL (whodunnit is nil)

**Step 3: Add whodunnit callback to ApplicationController**

Add to `app/controllers/application_controller.rb`:

```ruby
before_action :set_paper_trail_whodunnit

private

def user_for_paper_trail
  current_user&.id
end
```

**Step 4: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/requests/budget_items_spec.rb -e "activity tracking"
```
Expected: PASS

**Step 5: Commit**

```bash
git add app/controllers/application_controller.rb spec/requests/budget_items_spec.rb
git commit -m "feat: track user who made changes with PaperTrail"
```

---

## Task 9: Add Activity Log to Budget Model

**Files:**
- Modify: `app/models/monthly_budget.rb`
- Test: `spec/models/monthly_budget_spec.rb`

**Step 1: Write failing test**

Add to `spec/models/monthly_budget_spec.rb`:

```ruby
describe "#recent_activity" do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  it "returns combined versions from budget and items" do
    PaperTrail.request.whodunnit = user.id

    budget.update!(exchange_rate: 510)
    item = create(:budget_item, monthly_budget: budget, name: "Test")
    item.update!(amount: 200)

    activity = budget.recent_activity(limit: 10)

    expect(activity.length).to eq(3) # budget update + item create + item update
    expect(activity.first.created_at).to be >= activity.last.created_at
  end

  it "limits results" do
    PaperTrail.request.whodunnit = user.id

    5.times { |i| create(:budget_item, monthly_budget: budget, name: "Item #{i}") }

    activity = budget.recent_activity(limit: 3)

    expect(activity.length).to eq(3)
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/models/monthly_budget_spec.rb -e "recent_activity"
```
Expected: FAIL with "undefined method `recent_activity'"

**Step 3: Implement recent_activity method**

Add to `app/models/monthly_budget.rb`:

```ruby
def recent_activity(limit: 10)
  budget_versions = versions.order(created_at: :desc).limit(limit)

  item_ids = budget_items.pluck(:id)
  item_versions = PaperTrail::Version
    .where(item_type: "BudgetItem", item_id: item_ids)
    .order(created_at: :desc)
    .limit(limit)

  (budget_versions + item_versions)
    .sort_by(&:created_at)
    .reverse
    .first(limit)
end
```

**Step 4: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/models/monthly_budget_spec.rb -e "recent_activity"
```
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/monthly_budget.rb spec/models/monthly_budget_spec.rb
git commit -m "feat: add recent_activity method to MonthlyBudget"
```

---

## Task 10: Add Activity Display Helper

**Files:**
- Create: `app/helpers/activity_helper.rb`
- Test: `spec/helpers/activity_helper_spec.rb`

**Step 1: Write failing test**

Create `spec/helpers/activity_helper_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityHelper, type: :helper do
  let(:user) { create(:user, name: "Maria") }
  let(:current_user) { create(:user, name: "You") }

  before do
    allow(helper).to receive(:current_user).and_return(current_user)
  end

  describe "#format_activity" do
    context "for budget item creation" do
      let(:item) { create(:budget_item, name: "Netflix", amount: 15.99, currency: "USD") }

      it "formats create event" do
        version = item.versions.last
        version.update!(whodunnit: user.id.to_s)

        result = helper.format_activity(version)

        expect(result).to include("Maria")
        expect(result).to include("added")
        expect(result).to include("Netflix")
      end

      it "shows 'You' for current user" do
        version = item.versions.last
        version.update!(whodunnit: current_user.id.to_s)

        result = helper.format_activity(version)

        expect(result).to include("You")
      end
    end

    context "for budget item update" do
      let(:item) { create(:budget_item, name: "Rent", amount: 1400) }

      it "formats update event with change" do
        PaperTrail.request.whodunnit = user.id.to_s
        item.update!(amount: 1500)

        version = item.versions.last

        result = helper.format_activity(version)

        expect(result).to include("Maria")
        expect(result).to include("changed")
        expect(result).to include("Rent")
      end
    end

    context "for budget item deletion" do
      let(:item) { create(:budget_item, name: "Cable") }

      it "formats destroy event" do
        PaperTrail.request.whodunnit = user.id.to_s
        item.destroy!

        version = item.versions.last

        result = helper.format_activity(version)

        expect(result).to include("Maria")
        expect(result).to include("deleted")
        expect(result).to include("Cable")
      end
    end
  end

  describe "#activity_actor_name" do
    it "returns 'You' for current user" do
      expect(helper.activity_actor_name(current_user.id.to_s)).to eq("You")
    end

    it "returns user name for other users" do
      expect(helper.activity_actor_name(user.id.to_s)).to eq("Maria")
    end

    it "returns 'Someone' for nil whodunnit" do
      expect(helper.activity_actor_name(nil)).to eq("Someone")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/helpers/activity_helper_spec.rb
```
Expected: FAIL with "uninitialized constant ActivityHelper"

**Step 3: Create ActivityHelper**

Create `app/helpers/activity_helper.rb`:

```ruby
# frozen_string_literal: true

module ActivityHelper
  def format_activity(version)
    actor = activity_actor_name(version.whodunnit)
    action = activity_action(version.event)
    subject = activity_subject(version)

    "#{actor} #{action} #{subject}"
  end

  def activity_actor_name(whodunnit)
    return "Someone" if whodunnit.blank?
    return "You" if whodunnit.to_s == current_user.id.to_s

    User.find_by(id: whodunnit)&.name || "Someone"
  end

  def activity_time_ago(version)
    time_ago_in_words(version.created_at) + " ago"
  end

  private

  def activity_action(event)
    case event
    when "create" then "added"
    when "update" then "changed"
    when "destroy" then "deleted"
    else event
    end
  end

  def activity_subject(version)
    case version.item_type
    when "BudgetItem"
      item_name = version.reify&.name || version.object&.then { |o| YAML.safe_load(o, permitted_classes: [BigDecimal])["name"] } || "item"
      "\"#{item_name}\""
    when "MonthlyBudget"
      "budget settings"
    else
      version.item_type.underscore.humanize.downcase
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/helpers/activity_helper_spec.rb
```
Expected: PASS

**Step 5: Commit**

```bash
git add app/helpers/activity_helper.rb spec/helpers/activity_helper_spec.rb
git commit -m "feat: add ActivityHelper for formatting version history"
```

---

## Task 11: Add Activity Log UI to Budget Show

**Files:**
- Modify: `app/views/budgets/show.html.erb`
- Create: `app/views/budgets/_activity_log.html.erb`
- Test: `spec/system/budgets_spec.rb`

**Step 1: Write failing system test**

Add to `spec/system/budgets_spec.rb`:

```ruby
describe "activity log" do
  let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 5) }

  it "shows recent activity" do
    PaperTrail.request.whodunnit = user.id
    create(:budget_item, monthly_budget: budget, name: "Netflix", amount: 15.99)

    visit budget_path(budget)

    expect(page).to have_content("Recent Activity")
    expect(page).to have_content("Netflix")
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/system/budgets_spec.rb -e "activity log"
```
Expected: FAIL

**Step 3: Create activity log partial**

Create `app/views/budgets/_activity_log.html.erb`:

```erb
<% activities = budget.recent_activity(limit: 10) %>
<% if activities.any? %>
  <div class="mt-6 bg-white rounded-lg shadow p-4">
    <details class="group">
      <summary class="flex justify-between items-center cursor-pointer list-none">
        <h3 class="font-semibold text-gray-700">Recent Activity</h3>
        <span class="text-gray-400 group-open:rotate-180 transition-transform">▼</span>
      </summary>
      <ul class="mt-3 space-y-2 text-sm text-gray-600">
        <% activities.each do |version| %>
          <li class="flex justify-between items-center py-1 border-b border-gray-100 last:border-0">
            <span><%= format_activity(version) %></span>
            <span class="text-gray-400 text-xs"><%= activity_time_ago(version) %></span>
          </li>
        <% end %>
      </ul>
    </details>
  </div>
<% end %>
```

**Step 4: Include partial in show view**

Add at the bottom of `app/views/budgets/show.html.erb`, before the closing container div:

```erb
<%= render "activity_log", budget: @budget %>
```

**Step 5: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/system/budgets_spec.rb -e "activity log"
```
Expected: PASS

**Step 6: Commit**

```bash
git add app/views/budgets/show.html.erb app/views/budgets/_activity_log.html.erb spec/system/budgets_spec.rb
git commit -m "feat: add activity log UI to budget show page"
```

---

## Task 12: Update Budget Index to Show Shared Status

**Files:**
- Modify: `app/views/budgets/index.html.erb`
- Test: `spec/system/budgets_spec.rb`

**Step 1: Write failing system test**

Add to `spec/system/budgets_spec.rb` in the "household sharing" describe block:

```ruby
it "shows shared badge on index for shared budgets" do
  create(:monthly_budget, user: partner, year: 2026, month: 6, shared_with_household: true)

  visit budgets_path

  within(".household-budgets") do
    expect(page).to have_content("Shared")
  end
end
```

**Step 2: Run test to verify it fails**

Run:
```bash
bundle exec rspec spec/system/budgets_spec.rb -e "shows shared badge on index"
```
Expected: FAIL

**Step 3: Update index view to show shared badge**

In `app/views/budgets/index.html.erb`, find where household budgets are listed and add the shared badge. Look for something like:

```erb
<% @household_budgets.each do |budget| %>
```

And update to include:

```erb
<% @household_budgets.each do |budget| %>
  <div class="...">
    <%= link_to budget_path(budget), class: "..." do %>
      <span><%= Date::MONTHNAMES[budget.month] %> <%= budget.year %></span>
      <% if budget.shared_with_household? %>
        <span class="text-xs px-1 py-0.5 bg-blue-100 text-blue-700 rounded">Shared</span>
      <% end %>
    <% end %>
  </div>
<% end %>
```

**Step 4: Run test to verify it passes**

Run:
```bash
bundle exec rspec spec/system/budgets_spec.rb -e "shows shared badge on index"
```
Expected: PASS

**Step 5: Commit**

```bash
git add app/views/budgets/index.html.erb spec/system/budgets_spec.rb
git commit -m "feat: show shared badge on budget index page"
```

---

## Task 13: Data Migration for Existing Budgets

**Files:**
- Create: `db/migrate/*_set_shared_for_existing_household_budgets.rb`

**Step 1: Generate migration**

Run:
```bash
bundle exec rails generate migration SetSharedForExistingHouseholdBudgets
```

**Step 2: Write migration to preserve existing behavior**

```ruby
class SetSharedForExistingHouseholdBudgets < ActiveRecord::Migration[8.0]
  def up
    # For existing budgets, set shared_with_household to true if the owner is in a household
    # This preserves the previous behavior where household members could see each other's budgets
    execute <<-SQL
      UPDATE monthly_budgets
      SET shared_with_household = true
      WHERE user_id IN (
        SELECT user_id FROM household_memberships
      )
    SQL
  end

  def down
    execute <<-SQL
      UPDATE monthly_budgets
      SET shared_with_household = false
    SQL
  end
end
```

**Step 3: Run migration**

Run:
```bash
bundle exec rails db:migrate
```

**Step 4: Commit**

```bash
git add db/migrate/*_set_shared_for_existing_household_budgets.rb db/schema.rb
git commit -m "chore: data migration to preserve sharing for existing budgets"
```

---

## Task 14: Final Verification and Cleanup

**Step 1: Run full test suite**

Run:
```bash
bundle exec rspec
```
Expected: All tests pass

**Step 2: Run RuboCop**

Run:
```bash
bundle exec rubocop
```
Expected: No offenses

**Step 3: Run Brakeman**

Run:
```bash
bundle exec brakeman -q
```
Expected: No warnings

**Step 4: Check coverage**

Run:
```bash
bundle exec rspec
```
Expected: Coverage >= 94%

**Step 5: Update PENDING_FEATURES.md**

Remove the budget-access-control.md from future and note this as an in-progress feature or remove the old doc since we've addressed it differently.

**Step 6: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup for budget sharing feature"
```

---

## Summary

This implementation adds:

1. **PaperTrail** for tracking all changes to budgets and items
2. **shared_with_household** boolean for explicit sharing control
3. **Authorization updates** respecting sharing settings
4. **Owner-only delete** protection
5. **UI** for toggling sharing and viewing activity log
6. **Data migration** to preserve existing behavior

The feature is split into PRs:
- PR 1: PaperTrail + Data Model (Tasks 1-4)
- PR 2: Authorization + Sharing UI (Tasks 5-7)
- PR 3: Activity Tracking + Display (Tasks 8-12)
- PR 4: Data Migration + Polish (Tasks 13-14)
