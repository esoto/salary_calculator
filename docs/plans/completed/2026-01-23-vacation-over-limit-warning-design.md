# Vacation Days Over-Limit Warning Design

**Date:** 2026-01-23
**Status:** Draft
**Priority:** High
**Complexity:** Low

## Overview

Add a soft validation warning when users try to take more vacation days than they've earned. The warning explains the financial impact (dipping into holiday/aguinaldo savings) and requires acknowledgment via checkbox before saving.

**Scope:** Vacation days only. Holiday days remain unrestricted (holidays are unevenly distributed throughout the year; a future country-based holiday calendar feature will address this).

## Behavior

When a user saves a salary entry where their YTD vacation days taken exceeds days earned:

1. Display an amber warning banner explaining the impact
2. Show a checkbox: "I understand this affects my savings"
3. If checkbox is checked → allow save
4. If checkbox is not checked → show validation error

## Calculation Logic

```
entries_count = number of entries for the year (including current)
days_earned = entries_count * (vacation_days_per_year / 12.0)
days_taken_ytd = sum of vacation_days_taken for all entries in year (including current)
over_limit = days_taken_ytd > days_earned
over_by = days_taken_ytd - days_earned
```

**Key decisions:**
- Days earned based on **months with entries** (not calendar progression)
- **YTD balance** is considered (not per-entry isolation)
- Current entry **counts** toward days earned
- When editing, exclude persisted value before adding new value

## No Database Changes

All changes are code-only:
- Helper method on `User` model
- Custom validation on `SalaryEntry` model
- Virtual attribute for acknowledgment
- Form/controller updates

## Implementation Details

### User Model

New method to calculate vacation balance:

```ruby
def vacation_balance_for_year(year, exclude_entry: nil)
  entries = salary_entries.for_year(year)
  entries = entries.where.not(id: exclude_entry.id) if exclude_entry&.persisted?

  entries_count = entries.count
  entries_count += 1 if exclude_entry&.new_record? || exclude_entry

  days_earned = entries_count * (vacation_days_per_year / 12.0)
  days_taken = entries.sum(:vacation_days_taken)
  days_taken += exclude_entry.vacation_days_taken if exclude_entry

  { earned: days_earned, taken: days_taken, balance: days_earned - days_taken }
end
```

### SalaryEntry Model

```ruby
attr_accessor :vacation_over_limit_acknowledged

validate :vacation_within_limit_or_acknowledged

private

def vacation_within_limit_or_acknowledged
  return unless user&.vacation_enabled
  return if vacation_days_taken.to_f <= 0

  balance = user.vacation_balance_for_year(year, exclude_entry: self)
  return if balance[:balance] >= 0
  return if vacation_over_limit_acknowledged.present?

  errors.add(:base, "You're taking more vacation days than earned. Please acknowledge this to continue.")
end
```

### Form UI

Warning banner (amber theme) displayed when over limit:

```erb
<% if @over_vacation_limit %>
  <div class="bg-amber-50 border border-amber-200 rounded-lg p-4">
    <p class="text-amber-800 font-medium">Vacation days warning</p>
    <p class="text-amber-700 text-sm mt-1">
      You're taking <%= number_with_precision(@vacation_over_by, precision: 1) %>
      more days than earned. This means you'll need to use money from holiday
      and/or aguinaldo savings, affecting future finances.
    </p>
    <label class="flex items-center mt-3">
      <%= form.check_box :vacation_over_limit_acknowledged,
          class: "h-4 w-4 text-amber-600 rounded border-gray-300" %>
      <span class="ml-2 text-sm text-amber-800">I understand this affects my savings</span>
    </label>
  </div>
<% end %>
```

### Controller

- Permit `:vacation_over_limit_acknowledged` in strong params
- Calculate `@over_vacation_limit` and `@vacation_over_by` for view rendering

## Edge Cases

| Case | Handling |
|------|----------|
| Editing existing entry | Exclude persisted value from YTD sum before adding new value |
| Vacation disabled | Skip validation entirely |
| Zero days taken | Skip validation |
| First entry of year | 1 entry = 1 month earned |
| Other validation errors | Warning banner persists, checkbox state preserved |

## Testing

**Model specs (~8 tests):**
- Valid when vacation days taken ≤ days earned
- Valid when over limit but acknowledged
- Invalid when over limit and not acknowledged
- Valid when vacation_enabled is false
- Valid when vacation_days_taken is 0
- Correct balance calculation when editing existing entry
- `vacation_balance_for_year` returns correct values
- Balance calculation handles year with no entries

**System specs (~4-5 tests):**
- Entry within limit saves without warning
- Entry over limit shows warning banner
- Checking acknowledgment allows save
- Not checking shows validation error
- Warning persists with other validation errors

## Files to Modify

- `app/models/user.rb` - Add `vacation_balance_for_year` method
- `app/models/salary_entry.rb` - Add validation and virtual attribute
- `app/controllers/salary_entries_controller.rb` - Add strong param, calculate view vars
- `app/views/salary_entries/_form.html.erb` - Add warning banner with checkbox
- `spec/models/user_spec.rb` - Tests for balance method
- `spec/models/salary_entry_spec.rb` - Tests for validation
- `spec/system/salary_entries_spec.rb` - Integration tests

## Implementation Notes

- **Do NOT include Co-Authored-By or any Claude references in commit messages**
