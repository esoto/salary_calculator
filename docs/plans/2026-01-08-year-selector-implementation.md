# Year Selector on Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> **CRITICAL:** DO NOT include any Claude references in commit messages. Remove "Co-Authored-By: Claude" lines.

**Goal:** Add year selector dropdown to dashboard for viewing historical data from previous years.

**Architecture:** Add year parameter to dashboard controller with validation, query available years from user's entries, update view with dropdown that auto-submits on change via GET request.

**Tech Stack:** Rails 8, RSpec, Turbo (for form auto-submit), Tailwind CSS

---

## Task 1: Controller Spec - Year Parameter Defaults to Current Year

**Files:**
- Test: `spec/requests/dashboard_spec.rb`

**Step 1: Write failing test for default year**

Add to `spec/requests/dashboard_spec.rb` inside the existing `describe 'GET /dashboard'` block:

```ruby
context 'when no year parameter provided' do
  it 'defaults to current year' do
    get dashboard_path
    expect(assigns(:selected_year)).to eq(Date.current.year)
  end

  it 'shows current year in header cards' do
    get dashboard_path
    expect(response.body).to include("YTD #{Date.current.year}")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "when no year parameter provided"`

Expected: FAIL - `@selected_year` is nil

**Step 3: Implement controller logic for default year**

Modify `app/controllers/dashboard_controller.rb`:

```ruby
def show
  # Year selection with validation
  selected_year = params[:year].to_i
  selected_year = Date.current.year unless (2020..2100).cover?(selected_year)
  @selected_year = selected_year

  # YTD entries (use selected_year instead of current_year)
  ytd_entries = current_user.salary_entries.for_year(@selected_year)

  # Aguinaldo period entries
  aguinaldo_entries = current_user.salary_entries.for_aguinaldo_period(@selected_year)

  # ... rest of existing code unchanged ...

  # Update the @current_year assignment at the end
  @current_year = @selected_year
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "when no year parameter provided"`

Expected: PASS

**Step 5: Commit**

```bash
git add spec/requests/dashboard_spec.rb app/controllers/dashboard_controller.rb
git commit -m "feat: add year parameter support to dashboard controller

- Add year parameter handling with validation (2020-2100 range)
- Default to current year when no parameter provided
- Update dashboard to use selected year for all queries"
```

---

## Task 2: Controller Spec - Year Parameter Filtering

**Files:**
- Test: `spec/requests/dashboard_spec.rb`

**Step 1: Write failing test for year parameter filtering**

Add to `spec/requests/dashboard_spec.rb`:

```ruby
context 'when year parameter provided' do
  let(:user) { create(:user) }

  before do
    sign_in user

    # Create entries for 2024
    create(:salary_entry, user: user, year: 2024, month: 1,
           hours_worked: 160, hourly_rate: 50)
    create(:salary_entry, user: user, year: 2024, month: 2,
           hours_worked: 160, hourly_rate: 50)

    # Create entries for 2025
    create(:salary_entry, user: user, year: 2025, month: 1,
           hours_worked: 160, hourly_rate: 60)
  end

  it 'filters data by selected year' do
    get dashboard_path(year: 2024)

    expect(assigns(:selected_year)).to eq(2024)
    expect(assigns(:months_logged)).to eq(2)
    expect(assigns(:total_earnings)).to eq(160 * 50 * 2) # 2024 entries only
  end

  it 'shows different data for different years' do
    get dashboard_path(year: 2025)

    expect(assigns(:selected_year)).to eq(2025)
    expect(assigns(:months_logged)).to eq(1)
    expect(assigns(:total_earnings)).to eq(160 * 60) # 2025 entry only
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "when year parameter provided"`

Expected: Tests should PASS (logic already implemented in Task 1)

**Step 3: No implementation needed**

The year filtering logic from Task 1 already handles this.

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "when year parameter provided"`

Expected: PASS

**Step 5: Commit**

```bash
git add spec/requests/dashboard_spec.rb
git commit -m "test: add specs for year parameter filtering"
```

---

## Task 3: Controller Spec - Invalid Year Handling

**Files:**
- Test: `spec/requests/dashboard_spec.rb`

**Step 1: Write failing test for invalid year parameter**

Add to `spec/requests/dashboard_spec.rb`:

```ruby
context 'when invalid year parameter provided' do
  it 'defaults to current year for non-numeric year' do
    get dashboard_path(year: 'invalid')
    expect(assigns(:selected_year)).to eq(Date.current.year)
  end

  it 'defaults to current year for year below range' do
    get dashboard_path(year: 2019)
    expect(assigns(:selected_year)).to eq(Date.current.year)
  end

  it 'defaults to current year for year above range' do
    get dashboard_path(year: 2101)
    expect(assigns(:selected_year)).to eq(Date.current.year)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "when invalid year parameter provided"`

Expected: Tests should PASS (validation already implemented in Task 1)

**Step 3: No implementation needed**

The validation logic from Task 1 already handles invalid years.

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "when invalid year parameter provided"`

Expected: PASS

**Step 5: Commit**

```bash
git add spec/requests/dashboard_spec.rb
git commit -m "test: add specs for invalid year parameter handling"
```

---

## Task 4: Controller Spec - Available Years Query

**Files:**
- Test: `spec/requests/dashboard_spec.rb`

**Step 1: Write failing test for available years**

Add to `spec/requests/dashboard_spec.rb`:

```ruby
describe 'available years' do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  it 'returns empty array when user has no entries' do
    get dashboard_path
    expect(assigns(:available_years)).to eq([])
  end

  it 'returns years with entries in descending order' do
    create(:salary_entry, user: user, year: 2023, month: 1)
    create(:salary_entry, user: user, year: 2025, month: 1)
    create(:salary_entry, user: user, year: 2024, month: 1)

    get dashboard_path
    expect(assigns(:available_years)).to eq([2025, 2024, 2023])
  end

  it 'does not include other users years' do
    other_user = create(:user)
    create(:salary_entry, user: user, year: 2024, month: 1)
    create(:salary_entry, user: other_user, year: 2023, month: 1)

    get dashboard_path
    expect(assigns(:available_years)).to eq([2024])
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "available years"`

Expected: FAIL - `@available_years` is nil

**Step 3: Implement available years query**

Add to `app/controllers/dashboard_controller.rb` (before the existing calculations):

```ruby
def show
  # Year selection with validation
  selected_year = params[:year].to_i
  selected_year = Date.current.year unless (2020..2100).cover?(selected_year)
  @selected_year = selected_year

  # Available years for dropdown
  @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse

  # YTD entries (use selected_year instead of current_year)
  ytd_entries = current_user.salary_entries.for_year(@selected_year)

  # ... rest of existing code ...
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "available years"`

Expected: PASS

**Step 5: Commit**

```bash
git add spec/requests/dashboard_spec.rb app/controllers/dashboard_controller.rb
git commit -m "feat: add available years query for year selector"
```

---

## Task 5: View Spec - Year Selector UI Presence

**Files:**
- Test: `spec/views/dashboard/show.html.erb_spec.rb` (create if doesn't exist)

**Step 1: Write failing test for year selector visibility**

Create or modify `spec/views/dashboard/show.html.erb_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'dashboard/show.html.erb', type: :view do
  let(:user) { create(:user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:months_logged, 2)
    assign(:total_earnings, 16000)
    assign(:net_pay, 14000)
    assign(:aguinaldo_savings, 1333)
    assign(:vacation_savings, 1200)
    assign(:vacation_spent, 0)
    assign(:vacation_balance, 1200)
    assign(:holiday_savings, 667)
    assign(:holiday_spent, 0)
    assign(:holiday_balance, 667)
    assign(:vacation_days_earned, 3.0)
    assign(:vacation_days_taken, 0)
    assign(:vacation_days_available, 3.0)
    assign(:holiday_days_earned, 1.67)
    assign(:holiday_days_taken, 0)
    assign(:holiday_days_available, 1.67)
    assign(:total_savings, 2000)
    assign(:recent_entries, [])
    assign(:selected_year, 2025)
    assign(:current_year, 2025)
  end

  context 'when user has no entries' do
    before do
      assign(:available_years, [])
    end

    it 'does not show year selector' do
      render
      expect(rendered).not_to match(/Year:/)
    end
  end

  context 'when user has entries' do
    before do
      assign(:available_years, [2025, 2024, 2023])
    end

    it 'shows year selector dropdown' do
      render
      expect(rendered).to match(/Year:/)
      expect(rendered).to have_selector('select[name="year"]')
    end

    it 'includes all available years in dropdown' do
      render
      expect(rendered).to have_selector('option[value="2025"]', text: '2025')
      expect(rendered).to have_selector('option[value="2024"]', text: '2024')
      expect(rendered).to have_selector('option[value="2023"]', text: '2023')
    end

    it 'marks selected year as selected' do
      render
      expect(rendered).to have_selector('option[value="2025"][selected]')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/views/dashboard/show.html.erb_spec.rb`

Expected: FAIL - year selector not in rendered view

**Step 3: Implement year selector UI**

Modify `app/views/dashboard/show.html.erb` - update the header section:

```erb
<div class="flex flex-col md:flex-row md:justify-between md:items-center gap-4 mb-8">
  <div>
    <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
    <p class="text-gray-600">Welcome back, <%= current_user.name %></p>
  </div>

  <div class="flex flex-col md:flex-row gap-3">
    <% if @available_years.any? %>
      <%= form_with url: dashboard_path, method: :get, local: true,
                    data: { turbo_frame: "_top" },
                    class: "flex items-center gap-2" do |form| %>
        <label for="year" class="text-sm font-medium text-gray-700">Year:</label>
        <%= form.select :year,
                        options_for_select(@available_years, @selected_year),
                        {},
                        id: "year",
                        class: "border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500",
                        onchange: "this.form.requestSubmit()" %>
      <% end %>
    <% end %>

    <%= link_to "New Entry", new_salary_entry_path,
        class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-center" %>
  </div>
</div>
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/views/dashboard/show.html.erb_spec.rb`

Expected: PASS

**Step 5: Commit**

```bash
git add spec/views/dashboard/show.html.erb_spec.rb app/views/dashboard/show.html.erb
git commit -m "feat: add year selector dropdown to dashboard UI"
```

---

## Task 6: Integration Test - End-to-End Year Selection

**Files:**
- Test: `spec/requests/dashboard_spec.rb`

**Step 1: Write integration test**

Add to `spec/requests/dashboard_spec.rb`:

```ruby
describe 'year selection integration' do
  let(:user) { create(:user) }

  before do
    sign_in user

    # Create multi-year data
    create(:salary_entry, user: user, year: 2023, month: 1,
           hours_worked: 100, hourly_rate: 40)
    create(:salary_entry, user: user, year: 2024, month: 1,
           hours_worked: 150, hourly_rate: 50)
    create(:salary_entry, user: user, year: 2024, month: 2,
           hours_worked: 160, hourly_rate: 50)
    create(:salary_entry, user: user, year: 2025, month: 1,
           hours_worked: 170, hourly_rate: 60)
  end

  it 'displays correct data when switching years via parameter' do
    # View 2024 data
    get dashboard_path(year: 2024)
    expect(response).to have_http_status(:success)
    expect(assigns(:months_logged)).to eq(2)
    expect(assigns(:total_earnings)).to eq((150 * 50) + (160 * 50))

    # Switch to 2023 data
    get dashboard_path(year: 2023)
    expect(response).to have_http_status(:success)
    expect(assigns(:months_logged)).to eq(1)
    expect(assigns(:total_earnings)).to eq(100 * 40)

    # Switch to 2025 data
    get dashboard_path(year: 2025)
    expect(response).to have_http_status(:success)
    expect(assigns(:months_logged)).to eq(1)
    expect(assigns(:total_earnings)).to eq(170 * 60)
  end

  it 'includes year selector with all years in response' do
    get dashboard_path(year: 2024)

    expect(response.body).to include('Year:')
    expect(response.body).to include('value="2025"')
    expect(response.body).to include('value="2024"')
    expect(response.body).to include('value="2023"')
  end
end
```

**Step 2: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb -e "year selection integration"`

Expected: PASS (all functionality already implemented)

**Step 3: No implementation needed**

All functionality already implemented in previous tasks.

**Step 4: Run full test suite**

Run: `bundle exec rspec`

Expected: All tests pass

**Step 5: Commit**

```bash
git add spec/requests/dashboard_spec.rb
git commit -m "test: add integration tests for year selection"
```

---

## Task 7: Verify and Clean Up

**Step 1: Run full test suite**

Run: `bundle exec rspec`

Expected: All tests pass with high coverage

**Step 2: Check RuboCop**

Run: `bundle exec rubocop`

Expected: No offenses

If offenses found, fix with: `bundle exec rubocop -A`

**Step 3: Manual verification**

Start the server and test manually:

```bash
bin/rails server
```

Visit `http://localhost:3000/dashboard` and verify:
1. Year selector appears (if you have entries)
2. Selecting different years updates the data
3. URL includes `?year=XXXX` parameter
4. Invalid years default to current year
5. Mobile responsive layout works

**Step 4: Final commit if any fixes**

If any fixes were needed:

```bash
git add .
git commit -m "fix: address rubocop offenses and minor adjustments"
```

**Step 5: Done**

Feature complete. Ready for code review and PR.

---

## Testing Commands Summary

Run all specs:
```bash
bundle exec rspec
```

Run only dashboard specs:
```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Run with coverage:
```bash
COVERAGE=true bundle exec rspec
```

Check style:
```bash
bundle exec rubocop
```

---

## Notes for Implementation

- **TDD Required:** Write tests before implementation
- **100% Coverage:** Per CLAUDE.md requirements
- **No Claude References:** Remove Co-Authored-By lines from commits
- **Frequent Commits:** Commit after each task completion
- **DRY Principle:** Reuse existing scopes and patterns
- **YAGNI:** Only implement what's specified, no extras
