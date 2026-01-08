# Time Off Tracking Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> **IMPORTANT:** Do NOT include Claude references in commit messages. No "Generated with Claude Code", no "Co-Authored-By: Claude", etc.

**Goal:** Track vacation and holiday days taken each month, adjusting available days and savings balances.

**Architecture:** Add two decimal columns to salary_entries for days taken, update SalaryCalculations concern with spent/balance methods, modify total_savings to use balances, update dashboard and forms.

**Tech Stack:** Rails 8, RSpec, FactoryBot, Shoulda Matchers, Tailwind CSS v4

---

## Task 1: Add Database Columns

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_time_off_to_salary_entries.rb`
- Modify: `spec/factories/salary_entries.rb`

**Step 1: Generate migration**

Run: `rails generate migration AddTimeOffToSalaryEntries vacation_days_taken:decimal holiday_days_taken:decimal`

**Step 2: Update migration with precision and defaults**

```ruby
class AddTimeOffToSalaryEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :salary_entries, :vacation_days_taken, :decimal, precision: 4, scale: 2, default: 0, null: false
    add_column :salary_entries, :holiday_days_taken, :decimal, precision: 4, scale: 2, default: 0, null: false
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration completes successfully

**Step 4: Update factory**

Add to `spec/factories/salary_entries.rb`:

```ruby
vacation_days_taken { 0 }
holiday_days_taken { 0 }
```

**Step 5: Run existing tests to verify no regressions**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "Add vacation_days_taken and holiday_days_taken columns"
```

---

## Task 2: Add Model Validations

**Files:**
- Modify: `app/models/salary_entry.rb`
- Modify: `spec/models/salary_entry_spec.rb`

**Step 1: Write failing tests for validations**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe 'validations' do
  it { should validate_numericality_of(:vacation_days_taken).is_greater_than_or_equal_to(0) }
  it { should validate_numericality_of(:holiday_days_taken).is_greater_than_or_equal_to(0) }
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - validation not present

**Step 3: Add validations to model**

Add to `app/models/salary_entry.rb`:

```ruby
validates :vacation_days_taken, numericality: { greater_than_or_equal_to: 0 }
validates :holiday_days_taken, numericality: { greater_than_or_equal_to: 0 }
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Add validations for time off fields"
```

---

## Task 3: Add Calculation Methods

**Files:**
- Modify: `app/models/concerns/salary_calculations.rb`
- Modify: `spec/models/salary_entry_spec.rb`

**Step 1: Write failing tests for spent calculations**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe '#vacation_spent' do
  it 'calculates cost of vacation days taken' do
    entry = build(:salary_entry, hourly_rate: 50, vacation_days_taken: 2)
    expect(entry.vacation_spent).to eq(800) # 2 days * 8 hours * $50
  end

  it 'returns 0 when no days taken' do
    entry = build(:salary_entry, hourly_rate: 50, vacation_days_taken: 0)
    expect(entry.vacation_spent).to eq(0)
  end
end

describe '#holiday_spent' do
  it 'calculates cost of holiday days taken' do
    entry = build(:salary_entry, hourly_rate: 50, holiday_days_taken: 1.5)
    expect(entry.holiday_spent).to eq(600) # 1.5 days * 8 hours * $50
  end
end

describe '#vacation_balance' do
  it 'returns savings minus spent' do
    entry = build(:salary_entry, hourly_rate: 50, vacation_days_taken: 1)
    # vacation_savings = 12 hours * $50 = $600
    # vacation_spent = 1 day * 8 hours * $50 = $400
    expect(entry.vacation_balance).to eq(200)
  end
end

describe '#holiday_balance' do
  it 'returns savings minus spent' do
    entry = build(:salary_entry, hourly_rate: 60, holiday_days_taken: 0.5)
    # holiday_savings = 6.67 hours * $60 = $400
    # holiday_spent = 0.5 days * 8 hours * $60 = $240
    expect(entry.holiday_balance).to be_within(1).of(160)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - undefined method

**Step 3: Add methods to SalaryCalculations**

Add to `app/models/concerns/salary_calculations.rb`:

```ruby
def vacation_spent
  (vacation_days_taken || 0) * HOURS_PER_DAY * hourly_rate
end

def holiday_spent
  (holiday_days_taken || 0) * HOURS_PER_DAY * hourly_rate
end

def vacation_balance
  vacation_savings - vacation_spent
end

def holiday_balance
  holiday_savings - holiday_spent
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Add vacation/holiday spent and balance calculations"
```

---

## Task 4: Update total_savings to Use Balances

**Files:**
- Modify: `app/models/concerns/salary_calculations.rb`
- Modify: `spec/models/salary_entry_spec.rb`

**Step 1: Write test for updated total_savings**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe '#total_savings' do
  it 'reflects time off taken' do
    entry = build(:salary_entry, hours_worked: 160, hourly_rate: 50, vacation_days_taken: 1, holiday_days_taken: 0.5)

    # Without time off:
    # aguinaldo = 8000/12 = 666.67
    # vacation = 12 * 50 = 600
    # holiday = 6.67 * 50 = 333.33
    # total = 1600

    # With time off:
    # vacation_spent = 1 * 8 * 50 = 400
    # holiday_spent = 0.5 * 8 * 50 = 200
    # vacation_balance = 600 - 400 = 200
    # holiday_balance = 333.33 - 200 = 133.33
    # total = 666.67 + 200 + 133.33 = 1000

    expect(entry.total_savings).to be_within(1).of(1000)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - total_savings doesn't account for time off

**Step 3: Update total_savings method**

Modify `app/models/concerns/salary_calculations.rb`:

```ruby
def total_savings
  aguinaldo_savings + vacation_balance + holiday_balance
end
```

**Step 4: Run all tests**

Run: `bundle exec rspec`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Update total_savings to use vacation/holiday balances"
```

---

## Task 5: Update Form and Strong Parameters

**Files:**
- Modify: `app/views/salary_entries/_form.html.erb`
- Modify: `app/controllers/salary_entries_controller.rb`
- Modify: `spec/requests/salary_entries_spec.rb`

**Step 1: Write test for form submission with time off**

Add to `spec/requests/salary_entries_spec.rb`:

```ruby
describe "POST /salary_entries with time off" do
  let(:params_with_time_off) do
    { salary_entry: { month: 3, year: 2026, hours_worked: 160, hourly_rate: 50,
                      vacation_days_taken: 2, holiday_days_taken: 1 } }
  end

  it "saves time off fields" do
    post salary_entries_path, params: params_with_time_off
    entry = SalaryEntry.last
    expect(entry.vacation_days_taken).to eq(2)
    expect(entry.holiday_days_taken).to eq(1)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: FAIL - params not permitted

**Step 3: Update strong parameters**

In `app/controllers/salary_entries_controller.rb`, update `salary_entry_params`:

```ruby
def salary_entry_params
  params.require(:salary_entry).permit(:month, :year, :hours_worked, :hourly_rate,
                                        :vacation_days_taken, :holiday_days_taken)
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: All PASS

**Step 5: Update form view**

Add to `app/views/salary_entries/_form.html.erb` after hourly_rate field:

```erb
<div class="grid grid-cols-2 gap-4">
  <div>
    <%= form.label :vacation_days_taken, "Vacation days taken", class: "block text-sm font-medium text-gray-700 mb-1" %>
    <%= form.number_field :vacation_days_taken, step: 0.5, min: 0,
        class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
  </div>
  <div>
    <%= form.label :holiday_days_taken, "Holiday days taken", class: "block text-sm font-medium text-gray-700 mb-1" %>
    <%= form.number_field :holiday_days_taken, step: 0.5, min: 0,
        class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
  </div>
</div>
```

**Step 6: Run all tests**

Run: `bundle exec rspec`
Expected: All PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "Add time off fields to salary entry form"
```

---

## Task 6: Update Salary Entry Show Page

**Files:**
- Modify: `app/views/salary_entries/show.html.erb`

**Step 1: Add time off section to show page**

Add after the "Savings Breakdown" section, before "Net Pay":

```erb
<% if @salary_entry.vacation_days_taken > 0 || @salary_entry.holiday_days_taken > 0 %>
  <div class="border-t pt-6 mt-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-4">Time Off Taken</h2>
    <div class="space-y-3">
      <% if @salary_entry.vacation_days_taken > 0 %>
        <div class="flex justify-between">
          <span class="text-gray-600">Vacation (<%= @salary_entry.vacation_days_taken %> days)</span>
          <span class="font-medium text-red-600">-<%= format_currency(@salary_entry.vacation_spent) %></span>
        </div>
      <% end %>
      <% if @salary_entry.holiday_days_taken > 0 %>
        <div class="flex justify-between">
          <span class="text-gray-600">Holidays (<%= @salary_entry.holiday_days_taken %> days)</span>
          <span class="font-medium text-red-600">-<%= format_currency(@salary_entry.holiday_spent) %></span>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

**Step 2: Run all tests**

Run: `bundle exec rspec`
Expected: All PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "Show time off details on salary entry page"
```

---

## Task 7: Update Dashboard Controller

**Files:**
- Modify: `app/controllers/dashboard_controller.rb`
- Modify: `spec/requests/dashboard_spec.rb`

**Step 1: Write test for dashboard with time off**

Add to `spec/requests/dashboard_spec.rb`:

```ruby
context "with time off taken" do
  before do
    create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50,
           vacation_days_taken: 2, holiday_days_taken: 1)
  end

  it "displays available vacation days" do
    get dashboard_path
    # 1 month logged = 1.5 days earned, 2 taken = -0.5 available (or 0 if clamped)
    expect(response.body).to include("available")
  end

  it "displays days taken" do
    get dashboard_path
    expect(response.body).to include("taken")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: FAIL - doesn't show available/taken

**Step 3: Update dashboard controller**

Update `app/controllers/dashboard_controller.rb`:

```ruby
def show
  current_year = Date.current.year

  # YTD entries
  ytd_entries = current_user.salary_entries.for_year(current_year)

  # Aguinaldo period entries
  aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(current_year)

  # Summary stats (using SQL aggregation for performance)
  @months_logged = ytd_entries.count
  @total_earnings = ytd_entries.sum("hours_worked * hourly_rate")

  # Vacation/holiday savings and spent
  @vacation_savings = ytd_entries.sum("#{SalaryCalculations::VACATION_HOURS_PER_MONTH} * hourly_rate")
  @vacation_spent = ytd_entries.sum("COALESCE(vacation_days_taken, 0) * #{SalaryCalculations::HOURS_PER_DAY} * hourly_rate")
  @vacation_balance = @vacation_savings - @vacation_spent

  @holiday_savings = ytd_entries.sum("#{SalaryCalculations::HOLIDAY_HOURS_PER_MONTH} * hourly_rate")
  @holiday_spent = ytd_entries.sum("COALESCE(holiday_days_taken, 0) * #{SalaryCalculations::HOURS_PER_DAY} * hourly_rate")
  @holiday_balance = @holiday_savings - @holiday_spent

  @aguinaldo_savings = aguinaldo_entries.sum("hours_worked * hourly_rate / 12.0")

  # Days earned and taken
  @vacation_days_earned = @months_logged * SalaryCalculations::VACATION_DAYS_PER_MONTH
  @vacation_days_taken = ytd_entries.sum(:vacation_days_taken)
  @vacation_days_available = @vacation_days_earned - @vacation_days_taken

  @holiday_days_earned = @months_logged * SalaryCalculations::HOLIDAY_DAYS_PER_MONTH
  @holiday_days_taken = ytd_entries.sum(:holiday_days_taken)
  @holiday_days_available = @holiday_days_earned - @holiday_days_taken

  # Total savings and net pay (YTD)
  ytd_aguinaldo = ytd_entries.sum("hours_worked * hourly_rate / 12.0")
  @total_savings = ytd_aguinaldo + @vacation_balance + @holiday_balance
  @net_pay = @total_earnings - @total_savings

  # Recent entries
  @recent_entries = current_user.salary_entries.order(year: :desc, month: :desc).limit(5)

  @current_year = current_year
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Add time off tracking to dashboard controller"
```

---

## Task 8: Update Dashboard View

**Files:**
- Modify: `app/views/dashboard/show.html.erb`

**Step 1: Update vacation/holiday cards**

Update the Savings & Days Cards section:

```erb
<!-- Savings & Days Cards Row -->
<div class="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
  <!-- Vacation Savings -->
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-sm font-medium text-gray-500 uppercase">Vacation $</h3>
    <p class="text-xl font-bold text-green-600 mt-2"><%= format_currency(@vacation_balance) %></p>
    <p class="text-sm text-gray-500 mt-1">balance</p>
  </div>

  <!-- Vacation Days -->
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-sm font-medium text-gray-500 uppercase">Vacation Days</h3>
    <p class="text-xl font-bold text-green-600 mt-2"><%= number_with_precision(@vacation_days_available, precision: 1) %> available</p>
    <p class="text-sm text-gray-500 mt-1"><%= number_with_precision(@vacation_days_earned, precision: 1) %> earned, <%= number_with_precision(@vacation_days_taken, precision: 1) %> taken</p>
  </div>

  <!-- Holiday Savings -->
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-sm font-medium text-gray-500 uppercase">Holiday $</h3>
    <p class="text-xl font-bold text-green-600 mt-2"><%= format_currency(@holiday_balance) %></p>
    <p class="text-sm text-gray-500 mt-1">balance</p>
  </div>

  <!-- Holiday Days -->
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-sm font-medium text-gray-500 uppercase">Holiday Days</h3>
    <p class="text-xl font-bold text-green-600 mt-2"><%= number_with_precision(@holiday_days_available, precision: 1) %> available</p>
    <p class="text-sm text-gray-500 mt-1"><%= number_with_precision(@holiday_days_earned, precision: 1) %> earned, <%= number_with_precision(@holiday_days_taken, precision: 1) %> taken</p>
  </div>
</div>
```

**Step 2: Run all tests**

Run: `bundle exec rspec`
Expected: All PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "Update dashboard view with available days and balances"
```

---

## Task 9: Final Verification

**Step 1: Run all specs**

Run: `bundle exec rspec`
Expected: All PASS

**Step 2: Manual testing checklist**

- [ ] Create new entry with vacation days taken
- [ ] Edit entry to add holiday days taken
- [ ] Dashboard shows correct available days
- [ ] Dashboard shows correct savings balances
- [ ] Entry show page displays time off section
- [ ] Net pay increases when time off is taken

**Step 3: Final commit if any cleanup needed**

```bash
git status
# If clean, no commit needed
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Add database columns for time off |
| 2 | Add model validations |
| 3 | Add spent/balance calculation methods |
| 4 | Update total_savings to use balances |
| 5 | Update form and strong parameters |
| 6 | Update salary entry show page |
| 7 | Update dashboard controller |
| 8 | Update dashboard view |
| 9 | Final verification |

**Total: 9 tasks**
