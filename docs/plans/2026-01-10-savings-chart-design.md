# Savings Breakdown Chart Design

## Overview

Add a stacked column chart to the dashboard showing monthly accumulation of savings across three categories: Aguinaldo, Vacation, and Holiday savings. This provides visual insight into how savings build up throughout the selected year.

## Current State

The dashboard displays summary cards with total savings amounts for the selected year, but lacks visual representation of:
- Monthly progression of savings
- Breakdown of savings categories
- Trends in savings accumulation

## Solution

Add a Chartkick-based stacked column chart that visualizes monthly savings breakdown for the selected year.

## Architecture & Data Structure

### Charting Library

**Chartkick + Chart.js:**
- Use `chartkick` gem (~> 5.0) as Rails-friendly wrapper
- Chart.js v4 via importmap (already configured in Rails 8)
- No additional JavaScript compilation needed
- Works seamlessly with Turbo

**Why Chartkick:**
- Designed specifically for Rails applications
- Minimal JavaScript required
- Simple ERB helpers for chart rendering
- Handles Chart.js integration automatically
- Good documentation and Rails conventions

### Data Preparation

**Controller Method:**
Add private method `prepare_savings_chart_data` in `DashboardController`:

```ruby
def prepare_savings_chart_data
  entries_by_month = ytd_entries.group_by(&:month)

  data = {
    "Aguinaldo" => [],
    "Vacation" => [],
    "Holiday" => []
  }

  (1..12).each do |month|
    month_label = Date::MONTHNAMES[month][0..2] # Jan, Feb, Mar, etc.

    if entries_by_month[month]&.first
      entry = entries_by_month[month].first
      data["Aguinaldo"] << [month_label, entry.aguinaldo_savings]
      data["Vacation"] << [month_label, entry.vacation_savings]
      data["Holiday"] << [month_label, entry.holiday_savings]
    else
      data["Aguinaldo"] << [month_label, 0]
      data["Vacation"] << [month_label, 0]
      data["Holiday"] << [month_label, 0]
    end
  end

  data
end
```

**Model Methods:**
Add calculation methods to `SalaryEntry`:

```ruby
def aguinaldo_savings
  (hours_worked * hourly_rate) / 12.0
end

def vacation_savings
  SalaryCalculations::VACATION_HOURS_PER_MONTH * hourly_rate
end

def holiday_savings
  SalaryCalculations::HOLIDAY_HOURS_PER_MONTH * hourly_rate
end
```

**Data Structure:**
```ruby
{
  "Aguinaldo" => [["Jan", 666.67], ["Feb", 666.67], ...],
  "Vacation" => [["Jan", 600.00], ["Feb", 600.00], ...],
  "Holiday" => [["Jan", 333.33], ["Feb", 333.33], ...]
}
```

**Performance:**
- Reuses existing `ytd_entries` ActiveRecord relation
- O(n) processing where n = 12 months maximum
- No additional database queries
- Calculations in Ruby (lightweight for 12 data points)

## UI/UX Design

### Chart Placement

**Position:** Below summary cards (4 main cards + 4 savings/days cards), above Recent Entries table

**Layout Flow:**
1. Header with year selector
2. Summary cards row (4 cards)
3. Savings/days cards row (4 cards)
4. **→ Savings breakdown chart (NEW)**
5. Recent entries table

### Visual Design

**Chart Container:**
```erb
<div class="bg-white rounded-lg shadow p-6 mb-8">
  <h2 class="text-lg font-semibold text-gray-900 mb-4">
    Savings Breakdown <%= @selected_year %>
  </h2>

  <% if ytd_entries.any? %>
    <%= column_chart @savings_chart_data,
                     stacked: true,
                     colors: ["#3B82F6", "#10B981", "#F59E0B"],
                     prefix: "$",
                     thousands: ",",
                     library: {
                       plugins: {
                         legend: { position: 'top' }
                       }
                     } %>
  <% else %>
    <div class="text-center py-12 text-gray-500">
      <p>No data available for <%= @selected_year %>.</p>
      <p class="mt-2">
        <%= link_to "Add salary entries", new_salary_entry_path,
                    class: "text-blue-600 hover:text-blue-800" %>
        to see your savings breakdown.
      </p>
    </div>
  <% end %>
</div>
```

**Color Scheme:**
- **Aguinaldo:** Blue (#3B82F6) - Matches primary action color, largest savings category
- **Vacation:** Green (#10B981) - Positive/growth association, second category
- **Holiday:** Amber (#F59E0B) - Warm distinct color, completes the palette

**Chart Configuration:**
- **Type:** Stacked column chart (vertical bars)
- **X-axis:** Month labels (Jan, Feb, Mar, ..., Dec)
- **Y-axis:** Currency amounts with $ prefix and comma separators
- **Legend:** Positioned at top showing all three categories
- **Tooltips:** Display exact amounts on hover
- **Height:** Auto-responsive based on container
- **Responsive:** Adjusts for mobile viewports

### Empty State

When user has no entries for selected year:
- Show placeholder card with message
- Provide link to "Add salary entries"
- Maintain consistent card styling

## Controller Implementation

### Changes to DashboardController

**Add chart data preparation:**
```ruby
def show
  # ... existing code ...

  # Prepare chart data (uses existing ytd_entries)
  @savings_chart_data = prepare_savings_chart_data

  # ... rest of existing code ...
end

private

def prepare_savings_chart_data
  # Implementation as shown above
end
```

**Integration Points:**
- Uses existing `ytd_entries` variable (no new query)
- Respects selected year from year selector
- Returns empty/zero data for months without entries

## Model Implementation

### Changes to SalaryEntry

**Add convenience methods for chart data:**

```ruby
# Returns monthly aguinaldo contribution
def aguinaldo_savings
  (hours_worked * hourly_rate) / 12.0
end

# Returns monthly vacation savings
def vacation_savings
  SalaryCalculations::VACATION_HOURS_PER_MONTH * hourly_rate
end

# Returns monthly holiday savings
def holiday_savings
  SalaryCalculations::HOLIDAY_HOURS_PER_MONTH * hourly_rate
end
```

**Why These Methods:**
- DRY: Avoid duplicating calculation logic
- Testable: Can be unit tested independently
- Reusable: Could be used elsewhere in the app
- Clear: Explicit method names over inline calculations

## Testing Strategy

### Controller Specs (`spec/requests/dashboard_spec.rb`)

**Chart data structure tests:**
```ruby
describe 'savings chart data' do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'prepares chart data with all 12 months' do
    create(:salary_entry, user: user, year: 2025, month: 1,
           hours_worked: 160, hourly_rate: 50)

    get dashboard_path(year: 2025)

    expect(assigns(:savings_chart_data)).to be_a(Hash)
    expect(assigns(:savings_chart_data).keys).to match_array(["Aguinaldo", "Vacation", "Holiday"])
    expect(assigns(:savings_chart_data)["Aguinaldo"].length).to eq(12)
  end

  it 'includes correct calculations for months with entries' do
    create(:salary_entry, user: user, year: 2025, month: 3,
           hours_worked: 160, hourly_rate: 60)

    get dashboard_path(year: 2025)

    march_data = assigns(:savings_chart_data)["Aguinaldo"][2] # 0-indexed
    expect(march_data[0]).to eq("Mar")
    expect(march_data[1]).to eq(800.0) # (160 * 60) / 12
  end

  it 'shows zero for months without entries' do
    create(:salary_entry, user: user, year: 2025, month: 6)

    get dashboard_path(year: 2025)

    jan_data = assigns(:savings_chart_data)["Aguinaldo"][0]
    expect(jan_data[1]).to eq(0)
  end

  it 'respects selected year parameter' do
    create(:salary_entry, user: user, year: 2024, month: 1)
    create(:salary_entry, user: user, year: 2025, month: 1)

    get dashboard_path(year: 2024)

    # Should calculate based on 2024 data, not 2025
    expect(assigns(:savings_chart_data)).to be_present
  end
end
```

### Model Specs (`spec/models/salary_entry_spec.rb`)

**Calculation method tests:**
```ruby
describe 'savings calculation methods' do
  let(:entry) { create(:salary_entry, hours_worked: 160, hourly_rate: 50) }

  describe '#aguinaldo_savings' do
    it 'calculates monthly aguinaldo contribution' do
      # (160 * 50) / 12 = 666.67
      expect(entry.aguinaldo_savings).to eq(666.6666666666666)
    end
  end

  describe '#vacation_savings' do
    it 'calculates monthly vacation savings' do
      # VACATION_HOURS_PER_MONTH (12) * 50 = 600
      expect(entry.vacation_savings).to eq(600.0)
    end
  end

  describe '#holiday_savings' do
    it 'calculates monthly holiday savings' do
      # HOLIDAY_HOURS_PER_MONTH (6.67) * 50 = 333.5
      expect(entry.holiday_savings).to eq(333.5)
    end
  end
end
```

### View Specs (`spec/views/dashboard/show.html.erb_spec.rb`)

**Chart rendering tests:**
```ruby
describe 'savings breakdown chart' do
  context 'when user has entries for selected year' do
    before do
      assign(:savings_chart_data, {
        "Aguinaldo" => [["Jan", 666.67]],
        "Vacation" => [["Jan", 600.00]],
        "Holiday" => [["Jan", 333.33]]
      })
    end

    it 'renders the chart section' do
      render
      expect(rendered).to have_selector('.bg-white.rounded-lg.shadow')
      expect(rendered).to match(/Savings Breakdown/)
    end

    it 'includes chart element' do
      render
      expect(rendered).to include('column-chart')
    end
  end

  context 'when user has no entries for selected year' do
    before do
      assign(:savings_chart_data, {
        "Aguinaldo" => [],
        "Vacation" => [],
        "Holiday" => []
      })
      assign(:ytd_entries, [])
    end

    it 'shows empty state message' do
      render
      expect(rendered).to match(/No data available/)
      expect(rendered).to have_link('Add salary entries')
    end
  end
end
```

### Integration Tests

**Year selector interaction:**
```ruby
it 'updates chart when year changes' do
  create(:salary_entry, user: user, year: 2024, month: 1)
  create(:salary_entry, user: user, year: 2025, month: 1)

  get dashboard_path(year: 2024)
  chart_2024 = assigns(:savings_chart_data)

  get dashboard_path(year: 2025)
  chart_2025 = assigns(:savings_chart_data)

  expect(chart_2024).not_to eq(chart_2025)
end
```

### Manual Testing Checklist

- [ ] Chart.js loads correctly via importmap
- [ ] Chart renders with correct stacked columns
- [ ] Colors match design (blue, green, amber)
- [ ] Tooltips show correct currency amounts
- [ ] Legend displays all three categories
- [ ] Responsive behavior on mobile devices
- [ ] Empty state displays when no data
- [ ] Year selector updates chart data
- [ ] No console errors
- [ ] Accessibility: keyboard navigation works

## Dependencies

**Gemfile additions:**
```ruby
gem "chartkick", "~> 5.0"
```

**Importmap (already configured):**
Chart.js is already available via Rails 8's default importmap configuration.

**Bundle install:**
```bash
bundle install
```

## Implementation Summary

| Component | Changes |
|-----------|---------|
| Gemfile | Add chartkick gem |
| DashboardController | Add `prepare_savings_chart_data` method, assign `@savings_chart_data` |
| SalaryEntry model | Add `aguinaldo_savings`, `vacation_savings`, `holiday_savings` methods |
| dashboard/show.html.erb | Add chart section with empty state handling |
| dashboard_spec.rb | Add chart data tests (4 new tests) |
| salary_entry_spec.rb | Add calculation method tests (3 new tests) |
| dashboard view spec | Add chart rendering tests (2 contexts) |

**Estimated Complexity:** Medium (4-6 hours)
- Gem setup: 30 minutes
- Model methods & tests: 1 hour
- Controller logic & tests: 1.5 hours
- View integration & tests: 1.5 hours
- Manual testing & refinement: 1 hour

**Lines of Code:** ~150-200 lines
- Controller: ~25 lines
- Model: ~15 lines
- View: ~20 lines
- Tests: ~100 lines

## Benefits

**User Benefits:**
- Visual understanding of savings accumulation
- Easy identification of savings trends
- Month-by-month breakdown visibility
- Better financial planning insights

**Technical Benefits:**
- Reuses existing queries (no performance impact)
- Foundation for adding more charts later
- Minimal JavaScript complexity
- Works with existing year selector
- Maintains test coverage standards

## Future Enhancements (Out of Scope)

**Additional Charts:**
- Monthly earnings trend (line chart)
- Time off usage visualization (bar chart)
- Year-over-year comparison (multi-line chart)

**Chart Features:**
- Export chart as image/PDF
- Drill-down to month details on click
- Toggle series visibility
- Chart customization settings
- Cumulative view option

**Data Enhancements:**
- Show spent vs saved amounts
- Include net pay trend
- Compare against goals/targets
