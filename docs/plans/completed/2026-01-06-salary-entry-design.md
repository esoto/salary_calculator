# Salary Entry Design

## Overview

A simple salary tracking app for contractors paid by hour. Records monthly entries and calculates savings for Costa Rican labor benefits: aguinaldo (13th month), vacation days, and holidays.

## Data Model

### SalaryEntry

| Field        | Type    | Notes                        |
|--------------|---------|------------------------------|
| month        | integer | 1-12                         |
| year         | integer | e.g., 2025                   |
| hours_worked | decimal | hours worked that month      |
| hourly_rate  | decimal | rate per hour                |

**Constraints:**
- Unique index on `[month, year]`
- All fields required

## Business Logic

### Constants (hardcoded, configurable later)

```ruby
VACATION_DAYS = 18
HOLIDAYS = 10
HOURS_PER_DAY = 8

VACATION_HOURS_PER_MONTH = (VACATION_DAYS * HOURS_PER_DAY) / 12.0  # => 12.0
HOLIDAY_HOURS_PER_MONTH = (HOLIDAYS * HOURS_PER_DAY) / 12.0       # => 6.67
```

### Calculated Values (per entry)

- `monthly_salary` = hours_worked × hourly_rate
- `aguinaldo_savings` = monthly_salary / 12
- `vacation_savings` = 12.0 × hourly_rate
- `holiday_savings` = 6.67 × hourly_rate
- `total_savings` = aguinaldo + vacation + holidays

### Yearly Summary

- `SalaryEntry.for_year(year)` - scope for entries in a year
- `SalaryEntry.yearly_summary(year)` - aggregated totals

## Routes

```
GET    /salary_entries           → index (filterable by year)
GET    /salary_entries/new       → new form
POST   /salary_entries           → create
GET    /salary_entries/:id       → show with breakdown
GET    /salary_entries/:id/edit  → edit form
PATCH  /salary_entries/:id       → update
DELETE /salary_entries/:id       → delete
GET    /salary_entries/summary   → yearly summary
```

## Views

### Index
- Year filter dropdown (defaults to current year)
- Table: Month | Hours | Rate | Salary | Aguinaldo | Vacation | Holidays | Total Savings

### Show
- Entry details with full savings breakdown

### Summary
- Year selector
- Aggregated totals for selected year

## Validations

- `month`: presence, integer 1-12
- `year`: presence, integer (2020-2100)
- `hours_worked`: presence, numericality > 0
- `hourly_rate`: presence, numericality > 0
- Uniqueness: `[month, year]`

## Testing

- Model specs: validations, calculations, yearly summary
- Request specs: CRUD, filtering, summary endpoint
- Factory: `salary_entry` with defaults

## Future Enhancements (out of scope)

- User accounts (relate entries to users)
- Configurable vacation/holiday settings
- Multiple entries per month (different clients)
