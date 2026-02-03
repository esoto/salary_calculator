# Share via Link Design

**Date:** 2026-02-03
**Status:** Design Complete

## Overview

Allow budget owners to create shareable URLs that grant view-only access to external users (non-users or users outside the household). Each share link has a unique token, configurable visibility settings, and optional expiration.

## Key Decisions

- **View-only** - Recipients can see but not edit
- **Configurable visibility** - Owner chooses what to show: budget details, income sources, personal savings
- **Token-based security** - URL contains a secure random token (no password)
- **Optional expiration** - No expiration by default, owner can set one
- **Revocable** - Owner can delete the share link at any time
- **Named shares** - Optional name for easier identification (e.g., "For accountant")

## Data Model

### Table: `budget_shares`

```ruby
create_table :budget_shares do |t|
  t.references :monthly_budget, null: false, foreign_key: true
  t.string :token, null: false, index: { unique: true }
  t.string :name  # optional, e.g. "For accountant", "Mom"
  t.boolean :show_budget, default: true
  t.boolean :show_income_sources, default: false
  t.boolean :show_personal_savings, default: false
  t.datetime :expires_at  # null = never expires
  t.timestamps
end
```

### Model: `BudgetShare`

```ruby
class BudgetShare < ApplicationRecord
  belongs_to :monthly_budget

  validates :token, presence: true, uniqueness: true

  before_create :generate_token

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def display_name
    name.presence || "Share link ##{id}"
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
end
```

### Association in MonthlyBudget

```ruby
has_many :budget_shares, dependent: :destroy
```

## Routes

```ruby
# config/routes.rb

# Public route (no auth required)
get "shared/budgets/:token", to: "shared_budgets#show", as: :shared_budget

# Authenticated routes for managing shares
resources :budgets do
  resources :budget_shares, only: [:index, :create, :destroy], shallow: true
end
```

## Controllers

### SharedBudgetsController (public, no auth)

```ruby
class SharedBudgetsController < ApplicationController
  skip_before_action :require_authentication

  def show
    @share = BudgetShare.find_by!(token: params[:token])

    if @share.expired?
      render :expired and return
    end

    @budget = @share.monthly_budget
  end
end
```

### BudgetSharesController (authenticated, owner only)

```ruby
class BudgetSharesController < ApplicationController
  before_action :set_budget, only: [:index, :create]
  before_action :set_budget_share, only: [:destroy]
  before_action :authorize_owner

  def index
    @shares = @budget.budget_shares.order(created_at: :desc)
  end

  def create
    @share = @budget.budget_shares.build(share_params)
    # ... save and respond
  end

  def destroy
    @budget_share.destroy
    # ... respond with success
  end
end
```

## User Interface

### 1. Share Button on Budget Show Page

Add "Share" button next to "Edit Settings" in header.

### 2. Create Share Modal

```
┌─────────────────────────────────────────────────┐
│ Share Budget                              [X]   │
├─────────────────────────────────────────────────┤
│ Name (optional): [For accountant________]       │
│                                                 │
│ Include in shared view:                         │
│ ☑ Budget details (categories & items)           │
│ ☐ Income sources                                │
│ ☐ Personal savings                              │
│                                                 │
│ Expires: [Never ▼] or [Pick date...]            │
│                                                 │
│            [Cancel]  [Create Share Link]        │
└─────────────────────────────────────────────────┘
```

### 3. After Creation - Copy Link

```
┌─────────────────────────────────────────────────┐
│ Share Link Created!                             │
│                                                 │
│ [https://app.com/shared/budgets/abc123] [Copy]  │
│                                                 │
│            [Done]  [Manage Shares]              │
└─────────────────────────────────────────────────┘
```

### 4. Manage Shares List

On budget edit page or separate section:

```
┌─────────────────────────────────────────────────┐
│ Shared Links                                    │
├─────────────────────────────────────────────────┤
│ "For accountant"   Created Jan 15   [Revoke]    │
│ "Share link #2"    Expires Feb 28   [Revoke]    │
└─────────────────────────────────────────────────┘
```

### 5. Public Shared Budget View

```
┌─────────────────────────────────────────────────┐
│ 🔗 Shared Budget                                │
│ December 2026 • Shared by Esteban               │
├─────────────────────────────────────────────────┤
│ [Budget categories & items - if enabled]        │
│ [Income sources - if enabled]                   │
│ [Personal savings - if enabled]                 │
├─────────────────────────────────────────────────┤
│ This is a read-only shared view.                │
│ Want to create your own budgets? [Sign up]      │
└─────────────────────────────────────────────────┘
```

### 6. Expired Link View

```
┌─────────────────────────────────────────────────┐
│ Link Expired                                    │
│                                                 │
│ This share link is no longer valid.             │
│ Please contact the owner for a new link.        │
│                                                 │
│ [Go to Salary Calculator]                       │
└─────────────────────────────────────────────────┘
```

### 7. Invalid Token

Standard 404 page - don't reveal if token ever existed.

## Files to Create/Modify

| File | Change |
|------|--------|
| `db/migrate/*_create_budget_shares.rb` | Create budget_shares table |
| `app/models/budget_share.rb` | New model |
| `app/models/monthly_budget.rb` | Add has_many :budget_shares |
| `config/routes.rb` | Add share routes |
| `app/controllers/shared_budgets_controller.rb` | Public view controller |
| `app/controllers/budget_shares_controller.rb` | Manage shares controller |
| `app/views/shared_budgets/show.html.erb` | Public budget view |
| `app/views/shared_budgets/expired.html.erb` | Expired link view |
| `app/views/budgets/show.html.erb` | Add Share button |
| `app/views/budget_shares/_form.html.erb` | Create share form/modal |
| `app/views/budget_shares/_share.html.erb` | Share list item partial |
| `spec/models/budget_share_spec.rb` | Model tests |
| `spec/requests/shared_budgets_spec.rb` | Public access tests |
| `spec/requests/budget_shares_spec.rb` | Management tests |
| `spec/system/budget_sharing_spec.rb` | System tests |

## Security Considerations

- Token is 32 bytes of URL-safe base64 (256 bits of entropy)
- Invalid tokens return 404 (no information leakage)
- Expired shares show friendly message but no budget data
- Only budget owner can create/revoke shares
- Public view has no edit capabilities
