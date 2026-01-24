# Password Reset Completion Design

## Overview

Complete the existing password reset via email feature by adding the missing token generation, UI link, and comprehensive test coverage.

## Current State

Password reset is 90% implemented:
- ✓ Controller with reset flow (`PasswordsController`)
- ✓ Mailer with email template (`PasswordsMailer`)
- ✓ Views for request and update forms
- ✓ Routes configured
- ✗ Missing `generates_token_for` declaration in User model
- ✗ Missing "Forgot password?" link on login page
- ✗ Minimal test coverage (only 1 test)

## Data Model

### User Model

Add Rails 8's secure token generation:

```ruby
class User < ApplicationRecord
  generates_token_for :password_reset, expires_in: 15.minutes
  # ... existing code
end
```

**How it works:**
- `user.password_reset_token` generates a signed, expiring token
- `User.find_by_password_reset_token!(token)` verifies and finds user
- Tokens are stateless (no database columns needed)
- Tokens expire after 15 minutes
- Tokens invalidated after password change

## UI Changes

### Login Page

Add "Forgot password?" link below the password field:

```erb
<div>
  <%= form.label :password, class: "block text-sm font-medium text-gray-700 mb-1" %>
  <%= form.password_field :password, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
  <div class="text-right mt-1">
    <%= link_to "Forgot password?", new_password_path, class: "text-sm text-blue-600 hover:text-blue-800" %>
  </div>
</div>
```

### Existing Views (No Changes)

- Request reset form (`/passwords/new`) - already exists
- Update password form (`/passwords/:token/edit`) - already exists
- Email template - already exists

## Controller Flow

**Existing implementation (already working):**

1. **Request Reset** (`POST /passwords`)
   - User enters email address
   - Find user by email (nil if not found)
   - Send reset email via `deliver_later` (background job)
   - Always show success message (prevents email enumeration)

2. **Click Email Link** (`GET /passwords/:token/edit`)
   - Token verified via `find_by_password_reset_token!`
   - Invalid/expired tokens redirect with error
   - Shows password update form

3. **Update Password** (`PUT /passwords/:token`)
   - Validates password & confirmation match
   - Updates password (triggers `has_secure_password` validations)
   - Redirects to login on success

**Security features:**
- Timing-safe email lookup (no enumeration attack)
- Signed, expiring tokens (15 minutes)
- One-time use (token invalidated after password change)
- Generic success messages

## Testing Strategy

### Model Specs (`spec/models/user_spec.rb`)

```ruby
describe '#password_reset_token' do
  it 'generates a valid token'
  it 'token expires after 15 minutes'
  it 'token is invalidated after password change'
end
```

### Request Specs (`spec/requests/passwords_spec.rb`)

```ruby
describe 'POST /passwords' do
  it 'sends email for valid email address'
  it 'shows success message for invalid email (security)'
  it 'does not reveal if email exists'
end

describe 'GET /passwords/:token/edit' do
  it 'shows password form with valid token'
  it 'redirects with error for expired token'
  it 'redirects with error for invalid token'
end

describe 'PUT /passwords/:token' do
  it 'updates password with matching passwords'
  it 'fails with mismatched passwords'
  it 'cannot reuse token after password change'
end
```

### Mailer Specs (`spec/mailers/passwords_mailer_spec.rb`)

```ruby
describe '#reset' do
  it 'sends to correct email address'
  it 'includes reset link with token'
  it 'has correct subject line'
end
```

**Test tools:**
- Time travel for expiration tests (`travel_to`)
- `ActionMailer::Base.deliveries` to verify emails
- TDD approach: write failing tests first

## Implementation Summary

| Task | Description |
|------|-------------|
| 1 | Add `generates_token_for` to User model |
| 2 | Add "Forgot password?" link to login page |
| 3 | Write model specs for token generation |
| 4 | Write request specs for reset flow |
| 5 | Write mailer specs for email |
| 6 | Verify all specs pass |

**Estimated changes:**
- 1 line in User model
- 5 lines in login view
- ~50 lines of test code

## Future Enhancements (Out of Scope)

- Configurable token expiration time
- Track password reset attempts
- Admin password reset capability
