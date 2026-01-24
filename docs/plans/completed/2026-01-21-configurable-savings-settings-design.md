# Configurable Savings Settings Design

**Date:** 2026-01-21
**Status:** Approved
**PR:** TBD

## Overview

Allow users to customize vacation/holiday days per year and enable/disable each savings type (Aguinaldo, Vacation, Holiday) independently.

## Data Model

Add columns to `users` table:

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `vacation_days_per_year` | integer | 18 | Annual vacation days |
| `holiday_days_per_year` | integer | 10 | Annual holiday days |
| `hours_per_day` | integer | 8 | Working hours per day |
| `aguinaldo_enabled` | boolean | true | Include aguinaldo in savings |
| `vacation_enabled` | boolean | true | Include vacation in savings |
| `holiday_enabled` | boolean | true | Include holiday in savings |

**Validations:**
- `vacation_days_per_year`: 0-50
- `holiday_days_per_year`: 0-30
- `hours_per_day`: 1-12

## Calculation Changes

Replace hardcoded constants in `SalaryCalculations` concern with user-specific methods:

```ruby
def vacation_hours_per_month
  return 0 unless user.vacation_enabled
  (user.vacation_days_per_year * user.hours_per_day) / 12.0
end
```

When a savings type is disabled, its calculation returns 0.

Remove deprecated constants (`VACATION_DAYS`, `HOLIDAYS`, etc.) and update all references throughout the app.

## Settings UI

**Route:** `GET/PATCH /settings`

**Layout (progressive disclosure):**

```
Savings Preferences
-------------------
☑ Enable Aguinaldo savings

☑ Enable Vacation savings
   └─ Vacation days per year: [18]

☑ Enable Holiday savings
   └─ Holiday days per year: [10]

Work Schedule
-------------
Hours per day: [8]

[Save Settings]
```

When a checkbox is unchecked, its related input is hidden.

**Navigation:** Add "Settings" link to navbar between user name and "Log out".

## Dashboard Impact

| Setting Disabled | Dashboard Change |
|------------------|------------------|
| Aguinaldo | Hide "Aguinaldo 2025" card |
| Vacation | Hide "Vacation $" and "Vacation Days" cards |
| Holiday | Hide "Holiday $" and "Holiday Days" cards |

- **Net Pay** adjusts automatically (disabled savings not deducted)
- **Savings Chart** only shows enabled categories; hide chart if all disabled

## Salary Entry Form Impact

- If vacation disabled → hide `vacation_days_taken` field
- If holiday disabled → hide `holiday_days_taken` field

## Edge Cases

- User disables vacation but has existing `vacation_days_taken` entries → days taken still recorded, no savings impact
- User changes days mid-year → all calculations use new value (no historical tracking)
- New user registration → gets default values (18/10/8, all enabled)

## Migration

- All columns have defaults, existing users work immediately
- No data loss - purely additive change

## Implementation Notes

- **Do NOT include Co-Authored-By or any Claude references in commit messages**
