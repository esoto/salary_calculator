# Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> **IMPORTANT:** Do NOT include Claude references in commit messages. No "Generated with Claude Code", no "Co-Authored-By: Claude", etc.

**Goal:** Add a dashboard home page displaying earnings summary, savings, and accrued days.

**Architecture:** Create DashboardController with show action, add aguinaldo period scope to SalaryEntry, build Tailwind-styled dashboard view with summary cards and recent entries table.

**Tech Stack:** Rails 8, RSpec, FactoryBot, Shoulda Matchers, Tailwind CSS v4

---

## Task 1: Add Aguinaldo Period Scope

**Files:**
- Modify: `app/models/salary_entry.rb`
- Modify: `spec/models/salary_entry_spec.rb`

**Step 1: Write failing test for aguinaldo scope**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe '.for_aguinaldo_period' do
  let(:user) { create(:user) }

  it 'includes December of previous year' do
    entry = create(:salary_entry, user: user, month: 12, year: 2025)
    expect(user.salary_entries.for_aguinaldo_period(2026)).to include(entry)
  end

  it 'includes January through November of current year' do
    jan = create(:salary_entry, user: user, month: 1, year: 2026)
    nov = create(:salary_entry, user: user, month: 11, year: 2026)
    expect(user.salary_entries.for_aguinaldo_period(2026)).to include(jan, nov)
  end

  it 'excludes December of current year' do
    entry = create(:salary_entry, user: user, month: 12, year: 2026)
    expect(user.salary_entries.for_aguinaldo_period(2026)).not_to include(entry)
  end

  it 'excludes entries from other years' do
    entry = create(:salary_entry, user: user, month: 6, year: 2024)
    expect(user.salary_entries.for_aguinaldo_period(2026)).not_to include(entry)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - undefined method `for_aguinaldo_period`

**Step 3: Add scope to model**

```ruby
# app/models/salary_entry.rb
scope :for_aguinaldo_period, ->(year) {
  where("(year = ? AND month = 12) OR (year = ? AND month <= 11)", year - 1, year)
}
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Add for_aguinaldo_period scope to SalaryEntry"
```

---

## Task 2: Create DashboardController

**Files:**
- Create: `app/controllers/dashboard_controller.rb`
- Create: `spec/requests/dashboard_spec.rb`
- Modify: `config/routes.rb`

**Step 1: Write failing request specs**

```ruby
# spec/requests/dashboard_spec.rb
require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, name: "Test User") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /dashboard" do
    it "returns success" do
      get dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "displays user name" do
      get dashboard_path
      expect(response.body).to include("Test User")
    end
  end

  describe "GET / (root)" do
    it "shows dashboard" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
    end
  end

  context "when not logged in" do
    before { delete session_path }

    it "redirects to login" do
      get dashboard_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "with salary entries" do
    before do
      create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50)
      create(:salary_entry, user: user, month: 2, year: 2026, hours_worked: 140, hourly_rate: 50)
    end

    it "displays total earnings" do
      get dashboard_path
      expect(response.body).to include("15,000") # 160*50 + 140*50
    end

    it "displays months logged" do
      get dashboard_path
      expect(response.body).to include("2 of 12")
    end
  end

  context "data isolation" do
    it "does not show other user entries" do
      other_user = create(:user)
      create(:salary_entry, user: other_user, month: 1, year: 2026, hours_worked: 200, hourly_rate: 100)
      create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50)

      get dashboard_path
      expect(response.body).to include("8,000") # user's entry
      expect(response.body).not_to include("20,000") # other user's entry
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: FAIL - No route matches

**Step 3: Add routes**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [:new, :create]

  get "dashboard", to: "dashboard#show"
  root "dashboard#show"

  resources :salary_entries do
    collection do
      get :summary
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

**Step 4: Create controller**

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    current_year = Date.current.year

    # YTD entries
    ytd_entries = current_user.salary_entries.for_year(current_year)

    # Aguinaldo period entries
    aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(current_year)

    # Summary stats
    @months_logged = ytd_entries.count
    @total_earnings = ytd_entries.sum(&:monthly_salary)
    @vacation_savings = ytd_entries.sum(&:vacation_savings)
    @holiday_savings = ytd_entries.sum(&:holiday_savings)
    @aguinaldo_savings = aguinaldo_entries.sum(&:aguinaldo_savings)

    # Days earned (based on months logged)
    @vacation_days_earned = @months_logged * 1.5
    @holiday_days_earned = @months_logged * (10.0 / 12)

    # Recent entries
    @recent_entries = current_user.salary_entries.order(year: :desc, month: :desc).limit(5)

    @current_year = current_year
  end
end
```

**Step 5: Create placeholder view**

```erb
<%# app/views/dashboard/show.html.erb %>
<div class="max-w-6xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
  <p>Welcome back, <%= current_user.name %></p>
  <p>Total: <%= number_to_currency(@total_earnings) %></p>
  <p><%= @months_logged %> of 12 months</p>
</div>
```

**Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: All PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "Add DashboardController with basic stats"
```

---

## Task 3: Build Dashboard View

**Files:**
- Modify: `app/views/dashboard/show.html.erb`
- Modify: `app/helpers/salary_entries_helper.rb` (or create dashboard_helper.rb)

**Step 1: Update dashboard view with full layout**

```erb
<%# app/views/dashboard/show.html.erb %>
<div class="max-w-6xl mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-8">
    <div>
      <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
      <p class="text-gray-600">Welcome back, <%= current_user.name %></p>
    </div>
    <%= link_to "New Entry", new_salary_entry_path,
        class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg" %>
  </div>

  <!-- Summary Cards Row -->
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
    <!-- Aguinaldo Card -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-sm font-medium text-gray-500 uppercase">Aguinaldo <%= @current_year %></h3>
      <p class="text-2xl font-bold text-gray-900 mt-2"><%= format_currency(@aguinaldo_savings) %></p>
      <p class="text-sm text-gray-500 mt-1">Dec '<%= @current_year - 1 - 2000 %> - Nov '<%= @current_year - 2000 %></p>
    </div>

    <!-- Total Earnings Card -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-sm font-medium text-gray-500 uppercase">Total Earnings</h3>
      <p class="text-2xl font-bold text-gray-900 mt-2"><%= format_currency(@total_earnings) %></p>
      <p class="text-sm text-gray-500 mt-1">YTD <%= @current_year %></p>
    </div>

    <!-- Months Logged Card -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-sm font-medium text-gray-500 uppercase">Months Logged</h3>
      <p class="text-2xl font-bold text-gray-900 mt-2"><%= @months_logged %> of 12</p>
      <p class="text-sm text-gray-500 mt-1"><%= @current_year %></p>
    </div>
  </div>

  <!-- Savings & Days Cards Row -->
  <div class="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
    <!-- Vacation Savings -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-sm font-medium text-gray-500 uppercase">Vacation $</h3>
      <p class="text-xl font-bold text-green-600 mt-2"><%= format_currency(@vacation_savings) %></p>
      <p class="text-sm text-gray-500 mt-1">saved</p>
    </div>

    <!-- Vacation Days -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-sm font-medium text-gray-500 uppercase">Vacation Days</h3>
      <p class="text-xl font-bold text-green-600 mt-2"><%= number_with_precision(@vacation_days_earned, precision: 1) %> of 18</p>
      <p class="text-sm text-gray-500 mt-1">earned</p>
    </div>

    <!-- Holiday Savings -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-sm font-medium text-gray-500 uppercase">Holiday $</h3>
      <p class="text-xl font-bold text-green-600 mt-2"><%= format_currency(@holiday_savings) %></p>
      <p class="text-sm text-gray-500 mt-1">saved</p>
    </div>

    <!-- Holiday Days -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-sm font-medium text-gray-500 uppercase">Holiday Days</h3>
      <p class="text-xl font-bold text-green-600 mt-2"><%= number_with_precision(@holiday_days_earned, precision: 1) %> of 10</p>
      <p class="text-sm text-gray-500 mt-1">earned</p>
    </div>
  </div>

  <!-- Recent Entries -->
  <div class="bg-white rounded-lg shadow">
    <div class="px-6 py-4 border-b border-gray-200">
      <h2 class="text-lg font-semibold text-gray-900">Recent Entries</h2>
    </div>

    <% if @recent_entries.any? %>
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Month</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Hours</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Rate</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Salary</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <% @recent_entries.each do |entry| %>
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4">
                <%= link_to "#{month_name(entry.month)} #{entry.year}", entry,
                    class: "text-blue-600 hover:text-blue-800" %>
              </td>
              <td class="px-6 py-4 text-right"><%= format_hours(entry.hours_worked) %></td>
              <td class="px-6 py-4 text-right"><%= format_currency(entry.hourly_rate) %></td>
              <td class="px-6 py-4 text-right font-medium"><%= format_currency(entry.monthly_salary) %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <div class="px-6 py-8 text-center text-gray-500">
        <p>No entries yet.</p>
        <%= link_to "Create your first entry", new_salary_entry_path, class: "text-blue-600 hover:text-blue-800" %>
      </div>
    <% end %>

    <% if @recent_entries.any? %>
      <div class="px-6 py-4 border-t border-gray-200">
        <%= link_to "View all entries", salary_entries_path, class: "text-blue-600 hover:text-blue-800" %>
      </div>
    <% end %>
  </div>
</div>
```

**Step 2: Update ApplicationHelper to include SalaryEntriesHelper methods**

The `format_currency`, `format_hours`, and `month_name` helpers are already in `SalaryEntriesHelper`. Include it in ApplicationHelper or add `helper :all` to ApplicationController if not already present.

**Step 3: Run all tests**

Run: `bundle exec rspec`
Expected: All PASS

**Step 4: Commit**

```bash
git add -A
git commit -m "Build dashboard view with summary cards and recent entries"
```

---

## Task 4: Update Navigation

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Update nav to include Dashboard link**

Update the navigation in the layout to add a Dashboard link:

```erb
<%= link_to "Salary Calculator", root_path, class: "text-xl font-bold text-gray-900" %>
```

Also add "Entries" link in the nav when logged in:

```erb
<% if authenticated? %>
  <%= link_to "Entries", salary_entries_path, class: "text-gray-600 hover:text-gray-800" %>
  <span class="text-gray-600"><%= Current.user.name %></span>
  <%= button_to "Log out", session_path, method: :delete,
      class: "text-gray-600 hover:text-gray-800" %>
<% else %>
  ...
<% end %>
```

**Step 2: Run all tests**

Run: `bundle exec rspec`
Expected: All PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "Add Entries link to navigation"
```

---

## Task 5: Final Verification

**Step 1: Run all specs**

Run: `bundle exec rspec`
Expected: All PASS

**Step 2: Manual testing checklist**

- [ ] Visit root (redirects to login if not authenticated)
- [ ] Log in → lands on dashboard
- [ ] Dashboard shows user name
- [ ] Summary cards display correct values
- [ ] Recent entries table shows last 5 entries
- [ ] "View all entries" links to salary entries index
- [ ] "New Entry" button works
- [ ] Navigation shows "Entries" link
- [ ] Data isolation works (can't see other users' data)

**Step 3: Final commit if any cleanup needed**

```bash
git status
# If clean, no commit needed
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Add aguinaldo period scope to SalaryEntry |
| 2 | Create DashboardController with stats |
| 3 | Build dashboard view with Tailwind |
| 4 | Update navigation with Entries link |
| 5 | Final verification |

**Total: 5 tasks**
