# Budget Sharing & Activity Tracking Design

**Goal:** Add explicit budget sharing with household members and track all changes for accountability.

**Architecture:** Personal budgets by default with optional household sharing. PaperTrail tracks who made changes. Owner-only delete protection.

**Tech Stack:** PaperTrail gem, Rails authorization patterns

---

## Core Concept

- Every budget has one **owner** (the creator)
- Budgets are **private by default** - only visible to the owner
- Owner can **share with household** - all household members get full edit access
- Only the **owner can delete** the budget (prevents accidental loss)
- All changes are **tracked with PaperTrail** - see who added/modified/deleted what

## Data Model Changes

```
MonthlyBudget
├── user_id (owner - unchanged)
├── shared_with_household (boolean, default: false) ← NEW
└── has_paper_trail ← NEW

BudgetItem
└── has_paper_trail ← NEW
```

## Permission Logic

- **View**: Owner OR (shared AND in same household)
- **Edit items**: Owner OR (shared AND in same household)
- **Delete budget**: Owner only

## UI Changes

### Budget Edit/Settings Page

Add sharing toggle:

```
┌─────────────────────────────────────┐
│ Budget Settings                     │
├─────────────────────────────────────┤
│ Year: [2026 ▼]  Month: [February ▼] │
│ Exchange Rate: [505______]          │
│                                     │
│ ☐ Share with household              │
│   Partner can view and edit items   │
│                                     │
│ [Update Budget]     [Delete Budget] │
└─────────────────────────────────────┘
```

### Budget Show Page (viewing shared budget)

```
┌─────────────────────────────────────┐
│ February 2026          🏠 Shared    │
│ Maria's Budget                      │
└─────────────────────────────────────┘
```

### Activity Log

Collapsible section on budget show page:

```
Recent Activity ▼
├─ You added "Netflix" ($15.99) - 2 hours ago
├─ Maria changed "Rent" $1400→$1500 - yesterday
└─ You created this budget - 3 days ago
```

## Authorization Changes

### Controller Updates

```ruby
# app/controllers/concerns/budget_scoped.rb
def authorize_budget_access
  return if @budget.user == current_user
  return if @budget.shared_with_household? &&
            current_user.household&.members&.include?(@budget.user)
  redirect_to budgets_path, alert: "Access denied."
end

def authorize_budget_owner
  return if @budget.user == current_user
  redirect_to budgets_path, alert: "Only the owner can do this."
end
```

### Model Methods

```ruby
# app/models/monthly_budget.rb
def owned_by?(user)
  user_id == user.id
end

def accessible_by?(user)
  owned_by?(user) || (shared_with_household? && user.shares_household_with?(self.user))
end

def editable_by?(user)
  accessible_by?(user)
end
```

## PaperTrail Integration

### Gem Setup

```ruby
# Gemfile
gem 'paper_trail'
```

### Model Configuration

```ruby
# app/models/monthly_budget.rb
class MonthlyBudget < ApplicationRecord
  has_paper_trail
end

# app/models/budget_item.rb
class BudgetItem < ApplicationRecord
  has_paper_trail
end
```

### Track Who Made Changes

```ruby
# app/controllers/application_controller.rb
before_action :set_paper_trail_whodunnit
```

### Activity Query

```ruby
def recent_activity(limit: 10)
  budget_versions = versions.order(created_at: :desc).limit(limit)
  item_versions = PaperTrail::Version
    .where(item_type: 'BudgetItem')
    .where(item_id: budget_items.pluck(:id))
    .order(created_at: :desc)
    .limit(limit)

  (budget_versions + item_versions)
    .sort_by(&:created_at)
    .reverse
    .first(limit)
end
```

## Files to Create/Modify

| File | Change |
|------|--------|
| `Gemfile` | Add `paper_trail` gem |
| `db/migrate/*_add_shared_to_budgets.rb` | Add `shared_with_household` column |
| `db/migrate/*_create_versions.rb` | PaperTrail versions table |
| `app/models/monthly_budget.rb` | Add `has_paper_trail`, sharing methods |
| `app/models/budget_item.rb` | Add `has_paper_trail` |
| `app/controllers/concerns/budget_scoped.rb` | Update authorization logic |
| `app/controllers/budgets_controller.rb` | Add owner-only delete |
| `app/views/budgets/edit.html.erb` | Add sharing toggle |
| `app/views/budgets/show.html.erb` | Add shared badge, activity log |
| `app/helpers/budget_helper.rb` | Activity display helpers |

## Migration Strategy

**Breaking Change:** Currently household members can view/edit each other's budgets freely. After this change, budgets are private by default.

**Data Migration:** Set `shared_with_household: true` for existing budgets where users share a household (preserves current behavior for existing users).

## Future Enhancements (Not in Scope)

- Share via link/token for external access
- Invite by email
- Read-only vs edit permissions per share
- Undo/restore deleted items from activity log
