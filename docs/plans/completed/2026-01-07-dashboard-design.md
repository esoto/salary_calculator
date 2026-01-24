# Dashboard Design

## Overview

Add a dashboard as the home page for logged-in users, displaying summary stats for earnings, savings, and accrued vacation/holiday days.

## Data Model

### Aguinaldo Period (Dec → Nov)
- Aguinaldo is calculated from December of the previous year through November of the current year
- Example: "Aguinaldo 2026" = Dec 2025 → Nov 2026
- New scope: `for_aguinaldo_period(year)`

### YTD Stats (Calendar Year)
- Vacation savings: Sum of `vacation_savings` for current year entries
- Holiday savings: Sum of `holiday_savings` for current year entries
- Total earnings: Sum of `monthly_salary` for current year
- Months logged: Count of entries for current year

### Days Earned (Based on Months Logged)
- Vacation days: `months_logged × 1.5` (18 days / 12 months)
- Holiday days: `months_logged × 0.83` (10 days / 12 months)

### Recent Entries
- Last 5 entries across all years, ordered by year/month descending

## UI Layout

### Header
- "Dashboard" title with greeting: "Welcome back, {name}"
- "New Entry" button (top right)

### Summary Cards Row (3 cards)
| Aguinaldo 2026 | Total Earnings | Months Logged |
|----------------|----------------|---------------|
| $4,500.00      | $54,000.00     | 7 of 12       |
| Dec '25 - Nov  | YTD            | 2026          |

### Savings & Days Cards Row (4 cards)
| Vacation $  | Vacation Days | Holiday $   | Holiday Days |
|-------------|---------------|-------------|--------------|
| $3,600.00   | 10.5 of 18    | $2,000.00   | 5.8 of 10    |
| saved       | earned        | saved       | earned       |

### Recent Entries Table
- Last 5 entries
- Columns: Month/Year, Hours, Rate, Salary
- "View all entries" link at bottom

## Routes

```ruby
get "dashboard", to: "dashboard#show"
root "dashboard#show"  # Replace current root
```

## Architecture

### Controller
- `DashboardController#show`
- Requires authentication
- All queries scoped to `current_user`

### New Model Scope (SalaryEntry)
```ruby
scope :for_aguinaldo_period, ->(year) {
  where("(year = ? AND month = 12) OR (year = ? AND month <= 11)", year - 1, year)
}
```

### Dashboard Logic
- Keep in controller for now (simple enough)
- Extract to service/concern later if it grows

## Testing

- Request specs for dashboard route
- Model specs for `for_aguinaldo_period` scope
- Test empty state (no entries)
- Test data isolation (users only see own data)

## Future Enhancements (Out of Scope)

- Track vacations taken to reduce savings
- Year selector on dashboard
- Charts/graphs for trends
