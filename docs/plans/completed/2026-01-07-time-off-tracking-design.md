# Time Off Tracking Design

## Overview

Track vacation and holiday days taken each month, adjusting both available days and savings balances accordingly.

## Data Model

### New columns on salary_entries

```ruby
vacation_days_taken: decimal (precision: 4, scale: 2), default: 0
holiday_days_taken: decimal (precision: 4, scale: 2), default: 0
```

Using decimals to allow half-days (e.g., 0.5, 1.5).

### Validations

- Both fields >= 0
- Optional (defaults to 0)

## Calculations

### New methods in SalaryCalculations

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

### Updated total_savings

```ruby
def total_savings
  aguinaldo_savings + vacation_balance + holiday_balance
end
```

This means net_pay increases when you take time off (less being saved).

## Dashboard Updates

### Vacation/Holiday Cards

**Current:**
- Vacation $: savings amount
- Vacation Days: X of 18 earned

**Updated:**
- Vacation $: shows `vacation_balance` (savings - spent)
- Vacation Days: "X available" with subtitle "Y earned, Z taken"

Example:
```
Vacation Days          Holiday Days
8.5 available          6.2 available
10.5 earned, 2 taken   7.5 earned, 1.3 taken
```

## Form Updates

### Salary entry form (new/edit)

Add two optional fields below hours/rate:
- "Vacation days taken" (number input, step 0.5, default 0)
- "Holiday days taken" (number input, step 0.5, default 0)

### Salary entry show page

Add "Time Off" section after savings breakdown (only if days > 0):
- Vacation: X days taken → -$Y from savings
- Holidays: X days taken → -$Y from savings

## Testing

- Model specs for new calculation methods
- Request specs for form submission with time off fields
- Dashboard specs for available days display

## Future Enhancements (Out of Scope)

- Prevent taking more days than earned
- Carry over unused days to next year
- Track specific dates of time off
