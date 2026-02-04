# Shared Household Income Design

## Overview

Income sources inherit sharing permissions from the parent budget. If a user has a shared budget (`shared_with_household: true`), their income sources are accessible and editable by household members.

## Design

### Authorization Logic

Income sources follow the budget's sharing status:

```ruby
# IncomeSource model
def accessible_by?(check_user)
  return true if user_id == check_user.id
  user.monthly_budgets.where(shared_with_household: true).exists? &&
    check_user.shares_household_with?(user)
end

def editable_by?(check_user)
  # Linked income (to salary entries) - only linked user can edit
  return linked_user_id == check_user.id if linked_user_id.present?
  # Otherwise same as accessible
  accessible_by?(check_user)
end

def owned_by?(check_user)
  user_id == check_user.id
end
```

### Controller Changes

`IncomeSourcesController` needs:
1. Authorization checks using `accessible_by?` / `editable_by?`
2. Index shows household income sources when user has shared budgets
3. Create action sets `user_id` to current user (owner creates)
4. Edit/Update/Destroy check `editable_by?`

### View Changes

Income sources index shows:
- User's own income sources
- Household members' income sources (if they have shared budgets)
- Visual indicator for household member's income (like budgets do)

## Implementation Steps

1. Add authorization methods to `IncomeSource` model
2. Update `IncomeSourcesController` with authorization checks
3. Update index view to show household income sources
4. Add specs for new authorization logic

## No Migration Required

This approach reuses the existing `shared_with_household` column on `monthly_budgets` - no schema changes needed.
