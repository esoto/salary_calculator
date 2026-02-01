# Budget Access Control - Future Improvements

## Current Behavior

Household members have **full access** to each other's budgets:
- View budgets
- Edit/update budgets
- Delete budgets
- Create/edit/delete budget items

## Security Concern

Any household member can manipulate or delete another member's budget without audit trail.

## Proposed Solutions

### Option 1: Read-Only Sharing (Simple)

Split authorization into view vs. manage:

```ruby
# app/controllers/budgets_controller.rb
before_action :authorize_view_access, only: [:show]
before_action :authorize_manage_access, only: [:edit, :update, :destroy]

private

def authorize_view_access
  return if @budget.user == current_user
  return if current_user.household&.members&.include?(@budget.user)
  redirect_to budgets_path, alert: "Access denied."
end

def authorize_manage_access
  return if @budget.user == current_user
  redirect_to budgets_path, alert: "Access denied."
end
```

**Pros:** Simple, immediate security improvement
**Cons:** Limited collaboration

### Option 2: Audit Trail with PaperTrail

Keep full access but track all changes:

```ruby
# Gemfile
gem 'paper_trail'

# app/models/monthly_budget.rb
class MonthlyBudget < ApplicationRecord
  has_paper_trail
end

# app/models/budget_item.rb
class BudgetItem < ApplicationRecord
  has_paper_trail
end
```

**Pros:** Full collaboration, accountability via history
**Cons:** Doesn't prevent destructive actions, storage overhead

### Option 3: Shared Budgets with Roles (Recommended)

Create explicit sharing with role-based access:

```ruby
# Migration
create_table :budget_memberships do |t|
  t.references :monthly_budget, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.string :role, null: false, default: 'viewer' # viewer, editor, owner
  t.timestamps
end

# app/models/budget_membership.rb
class BudgetMembership < ApplicationRecord
  belongs_to :monthly_budget
  belongs_to :user

  enum :role, { viewer: 'viewer', editor: 'editor', owner: 'owner' }
end

# app/models/monthly_budget.rb
class MonthlyBudget < ApplicationRecord
  has_many :budget_memberships, dependent: :destroy
  has_many :shared_users, through: :budget_memberships, source: :user

  def can_view?(user)
    user_id == user.id || budget_memberships.exists?(user: user)
  end

  def can_edit?(user)
    user_id == user.id || budget_memberships.exists?(user: user, role: [:editor, :owner])
  end

  def can_delete?(user)
    user_id == user.id
  end
end
```

**Pros:** Flexible, explicit permissions, supports multiple budgets per month
**Cons:** More complex implementation, UI for managing sharing needed

## Recommended Approach

Combine Options 2 and 3:

1. **Phase 1:** Add PaperTrail for audit trail (quick win)
2. **Phase 2:** Implement BudgetMembership for explicit sharing
3. **Phase 3:** Add UI for managing budget sharing and viewing history

## Related Changes

- Update `authorize_budget_access` to check `BudgetMembership` roles
- Add sharing UI in budget show/edit pages
- Add activity log component showing recent changes
- Consider notifications for budget changes
