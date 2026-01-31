# Household Budget Feature Design

**Date:** 2026-01-31
**Status:** Design Complete

## Overview

A monthly budget planning feature that helps users allocate income across four categories: Fixed Expenses, Guilt-Free spending, Savings, and Investments. Supports dual currency display (CRC and USD) with configurable exchange rates, and integrates with existing salary entries for income tracking.

## Requirements

### Core Features
- Monthly budgets owned by users, shared with household members
- Four expense categories with percentage targets:
  - Fixed Expenses: 50-60%
  - Guilt-Free: 20-35%
  - Savings: 5-10%
  - Investments: 10%
- Dual currency display (Costa Rica Colones and US Dollars)
- Monthly exchange rate for currency conversion
- Visual warnings when categories exceed target percentages
- Paid/unpaid checkbox tracking for expense items
- Display salary entry savings (aguinaldo, vacation, holiday) alongside budget

### Income Sources
- Pull income from user's salary entries (hourly × hours)
- Support fixed monthly income amounts
- Multiple income sources per user

### Budget Creation
- Template-based: define items once, copy values from previous month
- When creating new month, auto-populate from previous month if exists
- Items persist with their amounts across months

### Household Sharing
- Budgets belong to individual users
- If user is in a household, members can view and edit each other's budgets
- Budget list shows owner's name: "Esteban's Budget - January 2026"

## Data Model

### MonthlyBudget
```ruby
# user_id: bigint (required)
# year: integer (2020-2100)
# month: integer (1-12)
# exchange_rate: decimal (CRC per 1 USD, e.g., 503.00)
# timestamps

# Indexes:
# - unique index on [user_id, year, month]
```

### BudgetItem
```ruby
# monthly_budget_id: bigint (required)
# name: string (required)
# category: string (enum: fixed, guilt_free, savings, investments)
# amount: decimal (required)
# currency: string (enum: CRC, USD)
# paid: boolean (default: false)
# position: integer (for ordering within category)
# timestamps
```

### IncomeSource
```ruby
# user_id: bigint (required, owner of this income source)
# linked_user_id: bigint (nullable, for salary entry lookup)
# name: string (required, e.g., "Main Job", "Side Project")
# amount: decimal (nullable, used when linked_user_id is null)
# currency: string (enum: CRC, USD)
# income_type: string (enum: hourly, fixed)
# active: boolean (default: true)
# timestamps
```

**Income Logic:**
- If `linked_user_id` is set: pull monthly income from that user's salary entry
- If `linked_user_id` is null: use the fixed `amount` value
- Allows mixing salary-based and fixed income sources

## Currency Handling

### Storage
- Each budget has an `exchange_rate` (CRC per 1 USD)
- Each item stores its native `currency` (CRC or USD)

### Display
- Dual columns showing both currencies
- CRC items: show CRC, calculate USD as `amount / exchange_rate`
- USD items: show USD, calculate CRC as `amount * exchange_rate`
- All totals shown in both currencies

### Percentage Calculations
- Convert all amounts to USD for percentage calculations
- Ensures consistent comparisons regardless of item currency

```ruby
def amount_in_usd(exchange_rate)
  currency == 'USD' ? amount : amount / exchange_rate
end

def category_percentage(category)
  category_total = items.where(category:).sum { |i| i.amount_in_usd(exchange_rate) }
  (category_total / total_income_usd * 100).round(2)
end
```

## Category Targets

```ruby
CATEGORY_TARGETS = {
  fixed: { min: 50, max: 60 },
  guilt_free: { min: 20, max: 35 },
  savings: { min: 5, max: 10 },
  investments: { min: 10, max: 10 }
}.freeze
```

Visual indicators:
- Green (✅): within target range
- Yellow (⚠️): within 5% of limit
- Red (🔴): outside target range

## Routes

```ruby
resources :budgets, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
  resources :budget_items, only: [:create, :update, :destroy] do
    member do
      patch :toggle_paid
    end
  end
end

resources :income_sources, only: [:index, :create, :update, :destroy]
```

## Controllers

### BudgetsController
- `index`: List user's budgets + household members' budgets (if in household)
- `show`: Main budget view with all categories
- `new/create`: Create budget, optionally copy from previous month
- `edit/update`: Update exchange rate
- `destroy`: Delete budget and all items

### BudgetItemsController
- `create`: Add item to category
- `update`: Edit item name/amount/currency
- `destroy`: Remove item
- `toggle_paid`: Quick checkbox toggle (Turbo Stream)

### IncomeSourcesController
- Manage income sources (settings-style page)
- Link to salary entries or set fixed amounts

## Access Control

- All users can create and manage their own budgets
- Household members can view and edit each other's budgets
- Non-household users only see their own budgets

```ruby
def authorize_budget_access
  return if @budget.user == current_user
  return if current_user.household&.members&.include?(@budget.user)

  redirect_to budgets_path, alert: "Access denied"
end
```

## UI Layout

### Desktop (4 columns)
```
┌──────────────────┬──────────────────┬──────────────────┬──────────────────┐
│ FIXED EXPENSES   │ GUILT-FREE       │ SAVINGS          │ INVESTMENTS      │
│ 61.7% ⚠️         │ 18.5% 🔴         │ 8.2% ✅          │ 10% ✅           │
│ (target 50-60%)  │ (target 20-35%)  │ (target 5-10%)   │ (target 10%)     │
├──────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ ☑ Casa    $1,590 │ ☐ Gastos M $198  │ ☐ Escuelas   $0  │ ☐ Retirement $150│
│ ☑ Netflix   $26  │ ☐ Gastos E $198  │ ☐ Marchamo  $83  │                  │
│ ...              │ ...              │ ...              │                  │
├──────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ Total: $2,336    │ Total: $465      │ Total: $131      │ Total: $150      │
│ [+ Add Item]     │ [+ Add Item]     │ [+ Add Item]     │ [+ Add Item]     │
└──────────────────┴──────────────────┴──────────────────┴──────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ INCOME & SUMMARY                          Exchange Rate: ₡503/$1 [Edit]     │
├─────────────────────────────────────────────────────────────────────────────┤
│ Income:  Esteban $4,960 + Side Project $500 = Total $5,460                  │
│ Expenses: $3,082 (56.4%)  |  Remaining: $2,378 (43.6%)                      │
│ Personal Savings: Aguinaldo $347 | Vacation $312 | Holiday $174 = $833     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Mobile (single column)
- Each category becomes a collapsible card
- Tap to expand/collapse
- Summary fixed at bottom

### Responsive Breakpoints
- Desktop (≥1024px): 4 columns
- Tablet (768-1023px): 2 columns
- Mobile (<768px): 1 column, collapsible cards

## Key Interactions

### Creating New Budget
1. Visit `/budgets` → see list of existing budgets
2. Click "New Budget" → select month/year
3. If previous month exists → auto-copy all items with amounts
4. If no previous → start empty, user adds items
5. Set exchange rate for the month

### Inline Editing (Turbo Streams)
- Click item → inline edit field
- Enter/blur → save via Turbo Stream
- Checkbox toggle → instant update
- No full page reloads

### Adding Items
- "+ Add Item" under each category
- Inline form: name, amount, currency
- Item appears via Turbo Stream

### Month Navigation
- `[◀ Prev]  January 2026  [Next ▶]`
- Creates budget for new month if doesn't exist (copying previous)

### Household Member Switching
- Tabs or dropdown: "My Budget | Mariana's Budget"
- Full edit access for household members

## Integration with Salary Entries

### Income from Salary Entries
```ruby
def income_from_salary_entry(user, year, month)
  entry = user.salary_entries.find_by(year:, month:)
  return 0 unless entry
  entry.hours_worked * entry.hourly_rate
end
```

### Display Personal Savings
Show calculated savings from salary entries in the budget view:
- Aguinaldo savings
- Vacation savings
- Holiday savings
- Total personal savings

These are read-only, calculated from the user's salary entry for that month.

## Testing Strategy

### Model Tests
- MonthlyBudget validations and associations
- BudgetItem currency conversion calculations
- IncomeSource income calculation logic
- Category percentage calculations
- Target range checking

### Request Tests
- CRUD operations for budgets and items
- Access control (own budget vs household member)
- Copy from previous month functionality
- Toggle paid functionality

### System Tests
- Create budget and add items
- Inline editing with Turbo
- Month navigation
- Household member budget switching
- Currency display and conversion

## Future Considerations (Not in MVP)

- Configurable percentage targets per user
- Budget templates (save/load item configurations)
- Historical comparison charts
- Export to CSV/PDF
- Recurring items (auto-create monthly)
