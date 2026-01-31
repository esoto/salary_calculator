# Household/Shared View Design

**Date:** 2026-01-26
**Status:** Draft
**Priority:** Low
**Complexity:** High

## Overview

Allow couples to see combined household finances while keeping individual dashboards. Each person maintains their own dashboard, plus a new "Household" dashboard showing combined totals from both partners.

**Use Case:** Couples wanting to see combined household income and savings for budgeting together.

## Data Model

```ruby
# Household
# - id
# - name (string, required)
# - invite_code (string, 6-char alphanumeric, unique)
# - timestamps

class Household < ApplicationRecord
  has_many :household_memberships, dependent: :destroy
  has_many :members, through: :household_memberships, source: :user

  validates :name, presence: true
  validates :invite_code, presence: true, uniqueness: true

  before_validation :generate_invite_code, on: :create

  def regenerate_invite_code!
    update!(invite_code: SecureRandom.alphanumeric(6).upcase)
  end

  private

  def generate_invite_code
    self.invite_code ||= SecureRandom.alphanumeric(6).upcase
  end
end

# HouseholdMembership (join table)
# - id
# - household_id (references)
# - user_id (references, unique - one household per user)
# - joined_at (datetime)
# - timestamps

class HouseholdMembership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  validates :user_id, uniqueness: { message: "is already in a household" }

  before_create { self.joined_at = Time.current }
end

# User additions
class User < ApplicationRecord
  has_one :household_membership, dependent: :destroy
  has_one :household, through: :household_membership
end
```

**Key constraints:**
- A user can belong to at most one household
- A household can have multiple members (typically 2 for couples)
- Salary entries stay owned by individual users (no changes to existing tables)

## User Flows

### Creating a Household
1. User goes to Settings page
2. Sees "Household" section (new card)
3. Clicks "Create Household"
4. Enters household name → household created
5. Sees invite code displayed (e.g., "ABC123")
6. Can copy code to share with partner

### Joining a Household
1. User goes to Settings page
2. Sees "Household" section with "Join Household" option
3. Enters 6-character invite code
4. If valid → joins household, sees confirmation
5. If invalid → error message "Invalid invite code"

### Leaving a Household
1. User goes to Settings → Household section
2. Clicks "Leave Household"
3. Confirmation dialog: "Are you sure? You'll lose access to the combined view."
4. Confirms → removed from household
5. If last member → household auto-deleted

### Viewing Household Dashboard
1. Navigation shows "Household" link (only if user is in a household)
2. Click → goes to `/household` dashboard
3. Shows combined totals from all members

## Household Dashboard

**Route:** `GET /household` → `HouseholdController#show`

**What it displays (combined from all members):**

| Metric | Calculation |
|--------|-------------|
| Total YTD Earnings | Sum of all members' gross pay |
| Total YTD Savings | Sum of all members' aguinaldo + vacation + holiday savings |
| Combined Savings Chart | Stacked by member (color-coded) |

**Breakdown by member:**
- Shows each member's name with their individual contribution

**UI Layout:**
```
┌─────────────────────────────────────────┐
│ Smith Household - 2026          [Year ▼]│
├─────────────────────────────────────────┤
│ Combined Earnings        │ $83,000 YTD  │
│ Combined Savings         │ $12,450 YTD  │
├─────────────────────────────────────────┤
│ By Member:                              │
│   Eduardo    $45,000 earnings  $6,750   │
│   Maria      $38,000 earnings  $5,700   │
├─────────────────────────────────────────┤
│ [Combined Savings Chart - stacked]      │
└─────────────────────────────────────────┘
```

**Access control:** Only household members can view; redirects non-members to dashboard with flash message.

## Settings UI - Household Card

```
┌─────────────────────────────────────────┐
│ Household                               │
├─────────────────────────────────────────┤
│ [If not in household]                   │
│   Create a household to share finances  │
│   with your partner.                    │
│                                         │
│   [Create Household] or [Join with Code]│
├─────────────────────────────────────────┤
│ [If in household]                       │
│   Smith Household                       │
│   Members: Eduardo, Maria               │
│                                         │
│   Invite Code: ABC123 [Copy] [Regenerate]│
│                                         │
│   [Leave Household]                     │
└─────────────────────────────────────────┘
```

## Routes

```ruby
# config/routes.rb
resources :households, only: [:create] do
  collection do
    post :join
  end
  member do
    delete :leave
    post :regenerate_code
  end
end

resource :household, only: [:show]  # GET /household (dashboard)
```

## Files to Create/Modify

**New files:**
- `app/models/household.rb`
- `app/models/household_membership.rb`
- `app/controllers/households_controller.rb` (plural - CRUD operations)
- `app/controllers/household_controller.rb` (singular - dashboard)
- `app/views/household/show.html.erb`
- `db/migrate/xxx_create_households.rb`
- `db/migrate/xxx_create_household_memberships.rb`
- `spec/models/household_spec.rb`
- `spec/models/household_membership_spec.rb`
- `spec/requests/households_spec.rb`
- `spec/requests/household_spec.rb`
- `spec/factories/households.rb`
- `spec/factories/household_memberships.rb`

**Modified files:**
- `app/models/user.rb` - Add household associations
- `app/views/settings/show.html.erb` - Add Household card
- `app/views/layouts/application.html.erb` - Add Household nav link (conditional)
- `spec/models/user_spec.rb` - Test household association

## Testing Strategy

**Model specs (~10 tests):**
- Household: validates name presence
- Household: generates unique invite_code on create
- Household: `regenerate_invite_code!` generates new code
- HouseholdMembership: validates user can only be in one household
- User: `#household` returns associated household or nil
- Household: `#combined_earnings_for_year` aggregates all members
- Household: `#combined_savings_for_year` aggregates all members

**Request specs (~12 tests):**
- `POST /households` creates household, adds creator as member
- `POST /households/join` with valid code joins household
- `POST /households/join` with invalid code shows error
- `POST /households/join` when already in household shows error
- `DELETE /households/:id/leave` removes membership
- `DELETE /households/:id/leave` as last member deletes household
- `GET /household` shows combined dashboard for members
- `GET /household` redirects non-members with flash message
- `POST /households/:id/regenerate_code` generates new code

**Navigation specs:**
- "Household" link appears only when user is in a household
- "Household" link hidden when user has no household

## Design Decisions

1. **Equal partners model** - No owner/editor/viewer roles; all members have equal access to view combined data, can only edit their own entries
2. **Join via code** - Simple 6-character alphanumeric code shared out-of-band (text, in person); no email invitation system needed
3. **One household per user** - Simplifies data model; user can leave and join a different household if needed
4. **Data stays with user** - Salary entries always belong to individual users; leaving household just removes shared view access
5. **Auto-delete empty households** - When last member leaves, household is automatically deleted

## Implementation Notes

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

- **IMPORTANT: Do NOT include Co-Authored-By or any Claude/AI references in commit messages**
