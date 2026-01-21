# Configurable Savings Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> **IMPORTANT:** Do NOT include Co-Authored-By or any Claude references in commit messages.

**Goal:** Allow users to customize vacation/holiday days per year and enable/disable each savings type independently.

**Architecture:** Add 6 columns to users table (3 integer settings, 3 boolean toggles). Replace hardcoded constants in SalaryCalculations with user-specific methods. Create Settings page with progressive disclosure UI. Update dashboard and entry form to respect user settings.

**Tech Stack:** Rails 8, SQLite, Tailwind CSS, Stimulus (for progressive disclosure)

---

### Task 1: Database Migration

**Files:**
- Create: `db/migrate/XXXXXX_add_savings_settings_to_users.rb`

**Step 1: Generate migration**

Run:
```bash
bin/rails generate migration AddSavingsSettingsToUsers vacation_days_per_year:integer holiday_days_per_year:integer hours_per_day:integer aguinaldo_enabled:boolean vacation_enabled:boolean holiday_enabled:boolean
```

**Step 2: Edit migration to add defaults**

```ruby
class AddSavingsSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :vacation_days_per_year, :integer, default: 18, null: false
    add_column :users, :holiday_days_per_year, :integer, default: 10, null: false
    add_column :users, :hours_per_day, :integer, default: 8, null: false
    add_column :users, :aguinaldo_enabled, :boolean, default: true, null: false
    add_column :users, :vacation_enabled, :boolean, default: true, null: false
    add_column :users, :holiday_enabled, :boolean, default: true, null: false
  end
end
```

**Step 3: Run migration**

Run: `bin/rails db:migrate`

**Step 4: Verify schema**

Run: `grep -A 15 'create_table "users"' db/schema.rb`
Expected: New columns visible with defaults

**Step 5: Commit**

```bash
git add db/migrate/*_add_savings_settings_to_users.rb db/schema.rb
git commit -m "feat: add savings settings columns to users table"
```

---

### Task 2: User Model Validations

**Files:**
- Modify: `app/models/user.rb`
- Test: `spec/models/user_spec.rb`

**Step 1: Write failing tests**

Add to `spec/models/user_spec.rb`:

```ruby
describe "savings settings validations" do
  it { should validate_numericality_of(:vacation_days_per_year).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(50) }
  it { should validate_numericality_of(:holiday_days_per_year).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(30) }
  it { should validate_numericality_of(:hours_per_day).is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12) }
end

describe "savings settings defaults" do
  let(:user) { User.create!(name: "Test", email_address: "test@example.com", password: "password123") }

  it "sets default vacation_days_per_year to 18" do
    expect(user.vacation_days_per_year).to eq(18)
  end

  it "sets default holiday_days_per_year to 10" do
    expect(user.holiday_days_per_year).to eq(10)
  end

  it "sets default hours_per_day to 8" do
    expect(user.hours_per_day).to eq(8)
  end

  it "enables aguinaldo by default" do
    expect(user.aguinaldo_enabled).to be true
  end

  it "enables vacation by default" do
    expect(user.vacation_enabled).to be true
  end

  it "enables holiday by default" do
    expect(user.holiday_enabled).to be true
  end
end
```

**Step 2: Run tests to verify failure**

Run: `bundle exec rspec spec/models/user_spec.rb -e "savings settings"`
Expected: FAIL (validations not implemented)

**Step 3: Add validations to User model**

Add to `app/models/user.rb`:

```ruby
validates :vacation_days_per_year, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
validates :holiday_days_per_year, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 30 }
validates :hours_per_day, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
```

**Step 4: Run tests to verify pass**

Run: `bundle exec rspec spec/models/user_spec.rb -e "savings settings"`
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/user.rb spec/models/user_spec.rb
git commit -m "feat: add savings settings validations to User model"
```

---

### Task 3: Update SalaryCalculations Concern

**Files:**
- Modify: `app/models/concerns/salary_calculations.rb`
- Test: `spec/models/salary_entry_spec.rb`

**Step 1: Write failing tests for user-specific calculations**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe "user-specific savings calculations" do
  let(:user) { User.create!(name: "Test", email_address: "calc@example.com", password: "password123") }
  let(:entry) { user.salary_entries.create!(year: 2025, month: 1, hours_worked: 160, hourly_rate: 50) }

  describe "#vacation_savings" do
    it "uses user's vacation_days_per_year setting" do
      user.update!(vacation_days_per_year: 24, hours_per_day: 8)
      # 24 days * 8 hours / 12 months * $50/hr = $800
      expect(entry.vacation_savings).to eq(800.0)
    end

    it "returns 0 when vacation is disabled" do
      user.update!(vacation_enabled: false)
      expect(entry.vacation_savings).to eq(0)
    end
  end

  describe "#holiday_savings" do
    it "uses user's holiday_days_per_year setting" do
      user.update!(holiday_days_per_year: 12, hours_per_day: 8)
      # 12 days * 8 hours / 12 months * $50/hr = $400
      expect(entry.holiday_savings).to eq(400.0)
    end

    it "returns 0 when holiday is disabled" do
      user.update!(holiday_enabled: false)
      expect(entry.holiday_savings).to eq(0)
    end
  end

  describe "#aguinaldo_savings" do
    it "returns 0 when aguinaldo is disabled" do
      user.update!(aguinaldo_enabled: false)
      expect(entry.aguinaldo_savings).to eq(0)
    end

    it "calculates normally when aguinaldo is enabled" do
      user.update!(aguinaldo_enabled: true)
      # 160 hours * $50/hr / 12 = $666.67
      expect(entry.aguinaldo_savings).to be_within(0.01).of(666.67)
    end
  end

  describe "#vacation_spent" do
    it "uses user's hours_per_day setting" do
      user.update!(hours_per_day: 6)
      entry.update!(vacation_days_taken: 2)
      # 2 days * 6 hours * $50/hr = $600
      expect(entry.vacation_spent).to eq(600.0)
    end
  end

  describe "#holiday_spent" do
    it "uses user's hours_per_day setting" do
      user.update!(hours_per_day: 6)
      entry.update!(holiday_days_taken: 1)
      # 1 day * 6 hours * $50/hr = $300
      expect(entry.holiday_spent).to eq(300.0)
    end
  end
end
```

**Step 2: Run tests to verify failure**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb -e "user-specific savings"`
Expected: FAIL

**Step 3: Update SalaryCalculations concern**

Replace `app/models/concerns/salary_calculations.rb`:

```ruby
# frozen_string_literal: true

module SalaryCalculations
  extend ActiveSupport::Concern

  def monthly_salary
    hours_worked * hourly_rate
  end

  def aguinaldo_savings
    return 0 unless user.aguinaldo_enabled
    monthly_salary / 12.0
  end

  def vacation_savings
    return 0 unless user.vacation_enabled
    vacation_hours_per_month * hourly_rate
  end

  def holiday_savings
    return 0 unless user.holiday_enabled
    holiday_hours_per_month * hourly_rate
  end

  def total_savings
    aguinaldo_savings + vacation_balance + holiday_balance
  end

  def net_pay
    monthly_salary - total_savings
  end

  def vacation_spent
    (vacation_days_taken || 0) * user.hours_per_day * hourly_rate
  end

  def holiday_spent
    (holiday_days_taken || 0) * user.hours_per_day * hourly_rate
  end

  def vacation_balance
    vacation_savings - vacation_spent
  end

  def holiday_balance
    holiday_savings - holiday_spent
  end

  private

  def vacation_hours_per_month
    (user.vacation_days_per_year * user.hours_per_day) / 12.0
  end

  def holiday_hours_per_month
    (user.holiday_days_per_year * user.hours_per_day) / 12.0
  end

  def vacation_days_per_month
    user.vacation_days_per_year / 12.0
  end

  def holiday_days_per_month
    user.holiday_days_per_year / 12.0
  end
end
```

**Step 4: Run tests to verify pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb -e "user-specific savings"`
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/concerns/salary_calculations.rb spec/models/salary_entry_spec.rb
git commit -m "feat: replace hardcoded constants with user-specific settings"
```

---

### Task 4: Update Dashboard Controller

**Files:**
- Modify: `app/controllers/dashboard_controller.rb`
- Test: `spec/requests/dashboard_spec.rb`

**Step 1: Write failing tests**

Add to `spec/requests/dashboard_spec.rb`:

```ruby
describe "user settings affecting calculations" do
  let(:user) { User.create!(name: "Settings Test", email_address: "settings@example.com", password: "password123") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "uses user's vacation_days_per_year for calculations" do
    user.update!(vacation_days_per_year: 24, hours_per_day: 8)
    user.salary_entries.create!(year: 2025, month: 1, hours_worked: 160, hourly_rate: 50)

    get dashboard_path, params: { year: 2025 }

    # 24 days * 8 hours / 12 months * $50/hr = $800
    expect(response.body).to include("$800.00")
  end

  it "hides aguinaldo card when aguinaldo is disabled" do
    user.update!(aguinaldo_enabled: false)
    user.salary_entries.create!(year: 2025, month: 1, hours_worked: 160, hourly_rate: 50)

    get dashboard_path, params: { year: 2025 }

    expect(response.body).not_to include("AGUINALDO")
  end

  it "hides vacation cards when vacation is disabled" do
    user.update!(vacation_enabled: false)
    user.salary_entries.create!(year: 2025, month: 1, hours_worked: 160, hourly_rate: 50)

    get dashboard_path, params: { year: 2025 }

    expect(response.body).not_to include("VACATION $")
    expect(response.body).not_to include("VACATION DAYS")
  end

  it "hides holiday cards when holiday is disabled" do
    user.update!(holiday_enabled: false)
    user.salary_entries.create!(year: 2025, month: 1, hours_worked: 160, hourly_rate: 50)

    get dashboard_path, params: { year: 2025 }

    expect(response.body).not_to include("HOLIDAY $")
    expect(response.body).not_to include("HOLIDAY DAYS")
  end
end
```

**Step 2: Run tests to verify failure**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "user settings affecting"`
Expected: FAIL

**Step 3: Update dashboard controller**

Update `app/controllers/dashboard_controller.rb` to use user settings:

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse

    selected_year = params[:year].to_i
    if (2020..2100).cover?(selected_year)
      @selected_year = selected_year
    else
      @selected_year = @available_years.first || Date.current.year
    end

    @ytd_entries = current_user.salary_entries.for_year(@selected_year)
    aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(@selected_year)

    @months_logged = @ytd_entries.count
    @total_earnings = @ytd_entries.sum("hours_worked * hourly_rate")

    # User settings
    @user = current_user
    hours_per_day = current_user.hours_per_day
    vacation_hours_per_month = (current_user.vacation_days_per_year * hours_per_day) / 12.0
    holiday_hours_per_month = (current_user.holiday_days_per_year * hours_per_day) / 12.0

    # Vacation/holiday savings and spent (only if enabled)
    if current_user.vacation_enabled
      @vacation_savings = @ytd_entries.sum("#{vacation_hours_per_month} * hourly_rate")
      @vacation_spent = @ytd_entries.sum("COALESCE(vacation_days_taken, 0) * #{hours_per_day} * hourly_rate")
      @vacation_balance = @vacation_savings - @vacation_spent
      @vacation_days_earned = @months_logged * (current_user.vacation_days_per_year / 12.0)
      @vacation_days_taken = @ytd_entries.sum(:vacation_days_taken)
      @vacation_days_available = @vacation_days_earned - @vacation_days_taken
    else
      @vacation_savings = @vacation_spent = @vacation_balance = 0
      @vacation_days_earned = @vacation_days_taken = @vacation_days_available = 0
    end

    if current_user.holiday_enabled
      @holiday_savings = @ytd_entries.sum("#{holiday_hours_per_month} * hourly_rate")
      @holiday_spent = @ytd_entries.sum("COALESCE(holiday_days_taken, 0) * #{hours_per_day} * hourly_rate")
      @holiday_balance = @holiday_savings - @holiday_spent
      @holiday_days_earned = @months_logged * (current_user.holiday_days_per_year / 12.0)
      @holiday_days_taken = @ytd_entries.sum(:holiday_days_taken)
      @holiday_days_available = @holiday_days_earned - @holiday_days_taken
    else
      @holiday_savings = @holiday_spent = @holiday_balance = 0
      @holiday_days_earned = @holiday_days_taken = @holiday_days_available = 0
    end

    if current_user.aguinaldo_enabled
      @aguinaldo_savings = aguinaldo_entries.sum("hours_worked * hourly_rate / 12.0")
    else
      @aguinaldo_savings = 0
    end

    @total_savings = @aguinaldo_savings + @vacation_balance + @holiday_balance
    @net_pay = @total_earnings - @total_savings

    @recent_entries = current_user.salary_entries.order(year: :desc, month: :desc).limit(5)
    @current_year = @selected_year

    @savings_chart_data = prepare_savings_chart_data(@ytd_entries)
  end

  private

  def prepare_savings_chart_data(ytd_entries)
    entries_by_month = ytd_entries.group_by(&:month)

    categories = {}
    categories["Aguinaldo"] = :aguinaldo_savings if current_user.aguinaldo_enabled
    categories["Vacation"] = :vacation_savings if current_user.vacation_enabled
    categories["Holiday"] = :holiday_savings if current_user.holiday_enabled

    categories.each_with_object({}) do |(name, method), result|
      result[name] = (1..12).map do |month|
        month_label = Date::MONTHNAMES[month][0..2]
        entry = entries_by_month[month]&.first
        value = entry ? entry.send(method).to_f : 0
        [ month_label, value ]
      end
    end
  end
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: Some may fail due to view changes needed

**Step 5: Commit**

```bash
git add app/controllers/dashboard_controller.rb spec/requests/dashboard_spec.rb
git commit -m "feat: update dashboard controller to use user settings"
```

---

### Task 5: Update Dashboard View

**Files:**
- Modify: `app/views/dashboard/show.html.erb`

**Step 1: Update view with conditional cards**

Wrap the Aguinaldo card with:
```erb
<% if @user.aguinaldo_enabled %>
  <!-- Aguinaldo card -->
<% end %>
```

Wrap Vacation $ and Vacation Days cards with:
```erb
<% if @user.vacation_enabled %>
  <!-- Vacation cards -->
<% end %>
```

Wrap Holiday $ and Holiday Days cards with:
```erb
<% if @user.holiday_enabled %>
  <!-- Holiday cards -->
<% end %>
```

Wrap chart section with:
```erb
<% if @ytd_entries.any? && (@user.aguinaldo_enabled || @user.vacation_enabled || @user.holiday_enabled) %>
  <!-- Chart section -->
<% end %>
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "user settings affecting"`
Expected: PASS

**Step 3: Commit**

```bash
git add app/views/dashboard/show.html.erb
git commit -m "feat: conditionally display dashboard cards based on user settings"
```

---

### Task 6: Settings Controller and Routes

**Files:**
- Create: `app/controllers/settings_controller.rb`
- Modify: `config/routes.rb`
- Test: `spec/requests/settings_spec.rb`

**Step 1: Write failing tests**

Create `spec/requests/settings_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { User.create!(name: "Settings User", email_address: "settings@example.com", password: "password123") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /settings" do
    it "renders the settings page" do
      get settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Settings")
    end

    it "displays current user settings" do
      get settings_path
      expect(response.body).to include("18") # default vacation days
      expect(response.body).to include("10") # default holiday days
      expect(response.body).to include("8")  # default hours per day
    end
  end

  describe "PATCH /settings" do
    it "updates user settings" do
      patch settings_path, params: {
        user: {
          vacation_days_per_year: 24,
          holiday_days_per_year: 15,
          hours_per_day: 7,
          aguinaldo_enabled: false,
          vacation_enabled: true,
          holiday_enabled: true
        }
      }

      expect(response).to redirect_to(settings_path)
      user.reload
      expect(user.vacation_days_per_year).to eq(24)
      expect(user.holiday_days_per_year).to eq(15)
      expect(user.hours_per_day).to eq(7)
      expect(user.aguinaldo_enabled).to be false
    end

    it "shows error for invalid settings" do
      patch settings_path, params: {
        user: { vacation_days_per_year: 100 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      delete session_path
      get settings_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
```

**Step 2: Run tests to verify failure**

Run: `bundle exec rspec spec/requests/settings_spec.rb`
Expected: FAIL (route not found)

**Step 3: Add route**

Add to `config/routes.rb`:

```ruby
resource :settings, only: [ :show, :update ]
```

**Step 4: Create controller**

Create `app/controllers/settings_controller.rb`:

```ruby
class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(settings_params)
      redirect_to settings_path, notice: "Settings saved successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(
      :vacation_days_per_year,
      :holiday_days_per_year,
      :hours_per_day,
      :aguinaldo_enabled,
      :vacation_enabled,
      :holiday_enabled
    )
  end
end
```

**Step 5: Run tests**

Run: `bundle exec rspec spec/requests/settings_spec.rb`
Expected: FAIL (view not found)

**Step 6: Commit controller and route**

```bash
git add app/controllers/settings_controller.rb config/routes.rb spec/requests/settings_spec.rb
git commit -m "feat: add settings controller and routes"
```

---

### Task 7: Settings View

**Files:**
- Create: `app/views/settings/show.html.erb`
- Create: `app/javascript/controllers/settings_controller.js`

**Step 1: Create settings view**

Create `app/views/settings/show.html.erb`:

```erb
<div class="max-w-2xl mx-auto px-4">
  <h1 class="text-2xl font-bold text-gray-900 mb-6">Settings</h1>

  <%= form_with model: @user, url: settings_path, method: :patch, class: "space-y-8", data: { controller: "settings" } do |form| %>
    <% if @user.errors.any? %>
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <h2 class="text-red-800 font-medium mb-2"><%= pluralize(@user.errors.count, "error") %> prevented saving:</h2>
        <ul class="list-disc list-inside text-red-700 text-sm">
          <% @user.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <!-- Savings Preferences -->
    <div class="bg-white rounded-lg shadow p-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Savings Preferences</h2>

      <div class="space-y-4">
        <!-- Aguinaldo -->
        <div class="flex items-center">
          <%= form.check_box :aguinaldo_enabled, class: "h-4 w-4 text-blue-600 rounded border-gray-300" %>
          <%= form.label :aguinaldo_enabled, "Enable Aguinaldo savings", class: "ml-2 text-sm font-medium text-gray-700" %>
        </div>

        <!-- Vacation -->
        <div>
          <div class="flex items-center">
            <%= form.check_box :vacation_enabled,
                class: "h-4 w-4 text-blue-600 rounded border-gray-300",
                data: { settings_target: "vacationToggle", action: "settings#toggleVacation" } %>
            <%= form.label :vacation_enabled, "Enable Vacation savings", class: "ml-2 text-sm font-medium text-gray-700" %>
          </div>
          <div class="ml-6 mt-2" data-settings-target="vacationFields" <%= "hidden" unless @user.vacation_enabled %>>
            <%= form.label :vacation_days_per_year, "Vacation days per year", class: "block text-sm text-gray-600 mb-1" %>
            <%= form.number_field :vacation_days_per_year, min: 0, max: 50,
                class: "w-24 border border-gray-300 rounded-lg px-3 py-2" %>
          </div>
        </div>

        <!-- Holiday -->
        <div>
          <div class="flex items-center">
            <%= form.check_box :holiday_enabled,
                class: "h-4 w-4 text-blue-600 rounded border-gray-300",
                data: { settings_target: "holidayToggle", action: "settings#toggleHoliday" } %>
            <%= form.label :holiday_enabled, "Enable Holiday savings", class: "ml-2 text-sm font-medium text-gray-700" %>
          </div>
          <div class="ml-6 mt-2" data-settings-target="holidayFields" <%= "hidden" unless @user.holiday_enabled %>>
            <%= form.label :holiday_days_per_year, "Holiday days per year", class: "block text-sm text-gray-600 mb-1" %>
            <%= form.number_field :holiday_days_per_year, min: 0, max: 30,
                class: "w-24 border border-gray-300 rounded-lg px-3 py-2" %>
          </div>
        </div>
      </div>
    </div>

    <!-- Work Schedule -->
    <div class="bg-white rounded-lg shadow p-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Work Schedule</h2>

      <div>
        <%= form.label :hours_per_day, "Hours per day", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= form.number_field :hours_per_day, min: 1, max: 12,
            class: "w-24 border border-gray-300 rounded-lg px-3 py-2" %>
      </div>
    </div>

    <div class="flex gap-4">
      <%= form.submit "Save Settings", class: "bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg cursor-pointer" %>
      <%= link_to "Cancel", dashboard_path, class: "bg-gray-200 hover:bg-gray-300 text-gray-800 px-6 py-2 rounded-lg" %>
    </div>
  <% end %>
</div>
```

**Step 2: Create Stimulus controller for progressive disclosure**

Create `app/javascript/controllers/settings_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["vacationToggle", "vacationFields", "holidayToggle", "holidayFields"]

  toggleVacation() {
    if (this.hasVacationFieldsTarget) {
      this.vacationFieldsTarget.hidden = !this.vacationToggleTarget.checked
    }
  }

  toggleHoliday() {
    if (this.hasHolidayFieldsTarget) {
      this.holidayFieldsTarget.hidden = !this.holidayToggleTarget.checked
    }
  }
}
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/requests/settings_spec.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add app/views/settings/show.html.erb app/javascript/controllers/settings_controller.js
git commit -m "feat: add settings view with progressive disclosure"
```

---

### Task 8: Add Settings Link to Navbar

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Add Settings link**

In `app/views/layouts/application.html.erb`, find:
```erb
<span class="text-gray-600"><%= Current.user.name %></span>
```

Change to:
```erb
<%= link_to Current.user.name, settings_path, class: "text-gray-600 hover:text-gray-800" %>
```

**Step 2: Verify manually**

Start server and verify Settings link appears in navbar.

**Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "feat: add settings link to navbar"
```

---

### Task 9: Update Salary Entry Form

**Files:**
- Modify: `app/views/salary_entries/_form.html.erb`
- Test: `spec/views/salary_entries/_form.html.erb_spec.rb`

**Step 1: Write failing tests**

Create `spec/views/salary_entries/_form.html.erb_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "salary_entries/_form", type: :view do
  let(:user) { User.create!(name: "Form Test", email_address: "form@example.com", password: "password123") }
  let(:entry) { user.salary_entries.build }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:salary_entry, entry)
  end

  it "shows vacation_days_taken when vacation is enabled" do
    user.update!(vacation_enabled: true)
    render partial: "salary_entries/form", locals: { salary_entry: entry }
    expect(rendered).to include("Vacation days taken")
  end

  it "hides vacation_days_taken when vacation is disabled" do
    user.update!(vacation_enabled: false)
    render partial: "salary_entries/form", locals: { salary_entry: entry }
    expect(rendered).not_to include("Vacation days taken")
  end

  it "shows holiday_days_taken when holiday is enabled" do
    user.update!(holiday_enabled: true)
    render partial: "salary_entries/form", locals: { salary_entry: entry }
    expect(rendered).to include("Holiday days taken")
  end

  it "hides holiday_days_taken when holiday is disabled" do
    user.update!(holiday_enabled: false)
    render partial: "salary_entries/form", locals: { salary_entry: entry }
    expect(rendered).not_to include("Holiday days taken")
  end
end
```

**Step 2: Run tests to verify failure**

Run: `bundle exec rspec spec/views/salary_entries/_form.html.erb_spec.rb`
Expected: FAIL

**Step 3: Update form partial**

In `app/views/salary_entries/_form.html.erb`, wrap the vacation/holiday fields:

```erb
<div class="grid grid-cols-2 gap-4">
  <% if current_user.vacation_enabled %>
    <div>
      <%= form.label :vacation_days_taken, "Vacation days taken", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.number_field :vacation_days_taken, step: 0.5, min: 0,
          class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>
  <% end %>
  <% if current_user.holiday_enabled %>
    <div>
      <%= form.label :holiday_days_taken, "Holiday days taken", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.number_field :holiday_days_taken, step: 0.5, min: 0,
          class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>
  <% end %>
</div>
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/views/salary_entries/_form.html.erb_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/views/salary_entries/_form.html.erb spec/views/salary_entries/_form.html.erb_spec.rb
git commit -m "feat: conditionally show days taken fields based on user settings"
```

---

### Task 10: Fix Existing Tests

**Files:**
- Modify: Various spec files that use old constants

**Step 1: Run full test suite**

Run: `bundle exec rspec`
Expected: Some failures due to removed constants

**Step 2: Update failing tests**

Update any tests that reference `SalaryCalculations::VACATION_DAYS`, `SalaryCalculations::HOLIDAYS`, or `SalaryCalculations::HOURS_PER_DAY` to use user settings instead.

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: PASS

**Step 4: Run RuboCop**

Run: `bundle exec rubocop`
Fix any offenses.

**Step 5: Commit**

```bash
git add -A
git commit -m "fix: update tests for user-specific settings"
```

---

### Task 11: Final Verification

**Step 1: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 2: Run RuboCop**

Run: `bundle exec rubocop`
Expected: No offenses

**Step 3: Manual testing checklist**

- [ ] Create new user → verify default settings (18/10/8, all enabled)
- [ ] Visit /settings → verify form displays correctly
- [ ] Toggle vacation off → verify field hides
- [ ] Save settings → verify persistence
- [ ] Visit dashboard → verify disabled cards are hidden
- [ ] Create entry → verify disabled day fields are hidden
- [ ] Change settings → verify calculations update

**Step 4: Create PR**

```bash
git push -u origin feature/configurable-settings
gh pr create --title "feat: configurable vacation/holiday settings" --body "$(cat <<'EOF'
## Summary
- Users can customize vacation days, holiday days, and hours per day
- Toggle to enable/disable Aguinaldo, Vacation, and Holiday savings independently
- New Settings page with progressive disclosure UI
- Dashboard and entry form adapt to user settings

## Test plan
- [ ] Run `bundle exec rspec` - all tests pass
- [ ] Manual verification per checklist above

Closes #TBD
EOF
)"
```
