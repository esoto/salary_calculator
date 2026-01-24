# Year Selector on Dashboard Design

## Overview

Add a year selector dropdown to the dashboard, allowing users to view historical data from previous years. Currently the dashboard only shows current year YTD data.

## UI/UX Design

### Year Selector Component

**Position:** Top-right area, next to the "New Entry" button in the header's flex container.

**Visual Style:**
- Dropdown displaying as "Year: [YYYY] ▾"
- Styled with Tailwind CSS matching existing design patterns
- Subtle border to indicate interactivity
- On mobile: stacks vertically below the title

**Behavior:**
- Uses Rails `form_with` with GET method
- Year parameter appears in URL (`/dashboard?year=2025`)
- Auto-submits on change (JavaScript via Turbo or vanilla)
- Selected year persists in URL (bookmarkable, shareable)

**Default State:**
- Defaults to current year on first visit
- Shows years in descending order (newest first)

**Empty State:**
- Year selector hidden when user has no entries
- Appears automatically once first entry is created

### Dropdown Contents

**Available Years:**
- Show only years where user has salary entries
- Query: `current_user.salary_entries.distinct.pluck(:year).sort.reverse`
- Keeps selector clean and relevant

## Backend Logic

### Controller Changes (`DashboardController#show`)

**New Parameters:**
1. Accept optional `year` parameter from query string
2. Validate year is numeric and within range (2020-2100)
3. Default to `Date.current.year` if invalid or missing
4. Query available years for dropdown
5. Pass `@available_years` and `@selected_year` to view

**Data Flow:**
```
User selects year → GET /dashboard?year=2024
→ Controller validates params[:year]
→ Use year for all queries (.for_year scope)
→ Render view with filtered data
```

**Modified Logic:**
```ruby
# Current: hard-coded current_year
current_year = Date.current.year

# New: parameter with validation
selected_year = params[:year].to_i
selected_year = Date.current.year unless (2020..2100).cover?(selected_year)

# Query available years
available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse
```

**Existing Queries:**
All queries already use `.for_year(year)` scope - no changes needed to:
- YTD entries calculation
- Aguinaldo period entries
- Summary stats (earnings, savings, days)
- Recent entries (already filtered by year)

### Security

**Validation:**
- Year parameter must be numeric
- Year must be within reasonable range (2020-2100)
- Invalid values default to current year

**Authorization:**
- User can only see their own data (enforced by `current_user.salary_entries`)
- Available years list scoped to user's entries

### Performance

**Additional Query:**
- Single query: `SELECT DISTINCT year FROM salary_entries WHERE user_id = ?`
- Minimal impact, returns small result set

**Existing Queries:**
- No changes to existing query logic
- All queries already scoped by year
- No N+1 queries introduced

## Testing Strategy

### Controller Specs (`spec/requests/dashboard_spec.rb`)

**Core Functionality:**
- Dashboard defaults to current year when no parameter provided
- Dashboard shows correct data when valid year parameter provided
- Dashboard handles invalid year parameter (defaults to current year)
- Dashboard handles non-numeric year parameter

**Available Years:**
- Available years list shows only years with user's entries
- Available years sorted descending (newest first)
- Other users' entries don't appear in available years

**Empty State:**
- Year selector not shown when user has no entries
- Year selector appears after first entry created

### View Specs (or System Specs)

**UI Elements:**
- Year selector dropdown appears when user has entries
- Year selector shows correct available years
- Selected year is highlighted in dropdown
- Form auto-submits on change (JavaScript behavior)

**Mobile Responsive:**
- Year selector stacks properly on mobile
- Dropdown remains functional on touch devices

### Test Data Setup

Use FactoryBot to create entries across multiple years:
```ruby
let(:user) { create(:user) }
before do
  create(:salary_entry, user: user, year: 2023, month: 12)
  create(:salary_entry, user: user, year: 2024, month: 1)
  create(:salary_entry, user: user, year: 2024, month: 2)
  create(:salary_entry, user: user, year: 2025, month: 1)
end
```

### Coverage Goals

- 100% test coverage per CLAUDE.md requirements
- TDD approach: write failing tests first
- All edge cases covered (invalid year, empty state, multiple years)

## Implementation Summary

| Task | Files Modified |
|------|----------------|
| 1 | Add year parameter handling to `app/controllers/dashboard_controller.rb` |
| 2 | Add year selector UI to `app/views/dashboard/show.html.erb` |
| 3 | Add controller specs to `spec/requests/dashboard_spec.rb` |
| 4 | Add view/system specs if needed |

**Estimated Complexity:** Medium (4-6 hours)

**Lines of Code:** ~50-70 lines (mostly tests)

## Future Enhancements (Out of Scope)

- Year comparison view (side-by-side 2024 vs 2025)
- Year-over-year percentage changes
- Multi-year charts and trends
- Export year data to CSV/PDF
