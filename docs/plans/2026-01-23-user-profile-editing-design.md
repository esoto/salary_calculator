# User Profile Editing Design

**Date:** 2026-01-23
**Status:** Draft
**Priority:** Medium
**Complexity:** Low

## Overview

Add profile editing capabilities to the existing Settings page, allowing users to update their name, email, and password.

**Scope:** Name editing, email editing (immediate update), password change (requires current password).

## UI Layout

Add a "Profile" card at the top of the existing Settings page:

```
Settings Page
├── Profile Card (NEW)
│   ├── Name field
│   ├── Email field
│   └── Change Password section
│       ├── Current password
│       ├── New password
│       └── Confirm new password
├── Savings Preferences Card (existing)
└── Work Schedule Card (existing)
```

## Behavior

- All profile fields submit with the existing "Save Settings" button
- Password fields are optional - leave blank to keep current password
- Current password only required when changing password (not for name/email changes)
- Email updates immediately (no confirmation email)
- Success message: "Settings saved successfully." (existing)

## Validation

**Password change validation:**
- If `new_password` is provided:
  - `current_password` must be provided and correct
  - `password_confirmation` must match `new_password`
- If `new_password` is blank → skip password change entirely

**Email validation:**
- Must be valid format (existing)
- Must be unique (existing)
- Normalized to lowercase (existing)

**Error messages:**
- "Current password is incorrect" - wrong current password
- "Password confirmation doesn't match" - mismatch
- "Email has already been taken" - duplicate email

## Implementation Details

### User Model

Add virtual attribute and custom validation:

```ruby
attr_accessor :current_password

validate :current_password_correct, if: :password_change_requested?

private

def password_change_requested?
  password.present?
end

def current_password_correct
  return if authenticate(current_password)
  errors.add(:current_password, "is incorrect")
end
```

### Settings Controller

Permit new params:

```ruby
def settings_params
  params.require(:user).permit(
    :name,
    :email_address,
    :current_password,
    :password,
    :password_confirmation,
    # existing params...
  )
end
```

### Form UI

Profile card (amber styling to match existing cards):

```erb
<!-- Profile Card -->
<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-lg font-semibold text-gray-900 mb-4">Profile</h2>

  <div class="space-y-4">
    <!-- Name -->
    <div>
      <%= form.label :name, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.text_field :name, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>

    <!-- Email -->
    <div>
      <%= form.label :email_address, "Email", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.email_field :email_address, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>

    <!-- Password Change -->
    <div class="border-t pt-4 mt-4">
      <p class="text-sm font-medium text-gray-700 mb-3">Change Password</p>
      <p class="text-xs text-gray-500 mb-3">Leave blank to keep current password</p>

      <div class="space-y-3">
        <%= form.label :current_password, class: "block text-sm text-gray-600" %>
        <%= form.password_field :current_password, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>

        <%= form.label :password, "New password", class: "block text-sm text-gray-600 mt-3" %>
        <%= form.password_field :password, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>

        <%= form.label :password_confirmation, "Confirm new password", class: "block text-sm text-gray-600 mt-3" %>
        <%= form.password_field :password_confirmation, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
      </div>
    </div>
  </div>
</div>
```

## No Database Changes

All changes are code-only:
- Virtual attribute for `current_password`
- Custom validation on User model
- Controller param updates
- View updates

## Testing

**Model specs (~5 tests):**
- Valid when changing password with correct current password
- Invalid when changing password without current password
- Invalid when current password is incorrect
- Invalid when password confirmation doesn't match
- Skips password validation when password fields blank

**Request specs (~5 tests):**
- Successfully updates name
- Successfully updates email
- Successfully changes password
- Shows error for wrong current password
- Shows error for mismatched confirmation

## Files to Modify

- `app/models/user.rb` - Add `current_password` attr_accessor, password validation
- `app/controllers/settings_controller.rb` - Permit new params
- `app/views/settings/show.html.erb` - Add Profile card
- `spec/models/user_spec.rb` - Tests for password validation
- `spec/requests/settings_spec.rb` - Integration tests

## Implementation Notes

- **Do NOT include Co-Authored-By or any Claude references in commit messages**
