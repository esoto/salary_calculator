# User Authentication Design

## Overview

Add user accounts to the salary calculator so each user has private salary entries. Uses Rails 8 built-in authentication with open registration.

## Data Model

### User

| Field | Type | Notes |
|-------|------|-------|
| email_address | string | Required, unique (from generator) |
| password_digest | string | bcrypt hashed (from generator) |
| name | string | Required, for personalization |
| default_hourly_rate | decimal | Optional, pre-fills forms |

### SalaryEntry Changes

- Add `user_id` foreign key (required, not null)
- Add `belongs_to :user`
- Update uniqueness: `[month, year, user_id]` (each user can have one entry per month)

### Associations

```ruby
User has_many :salary_entries, dependent: :destroy
SalaryEntry belongs_to :user
```

## Authentication Flow

### Rails 8 Generator Provides
- `User` model with `has_secure_password`
- `Session` model for tracking sessions
- `SessionsController` (login/logout)
- `PasswordsController` (password reset)
- `Authentication` concern with `require_authentication` and `current_user`

### Custom Additions
- `RegistrationsController` for signup
- Registration form: email, password, name, default_hourly_rate
- Migration for custom User fields (name, default_hourly_rate)

### Access Control
- All salary entry pages require login
- Users only see/edit their own entries
- Redirect to login if not authenticated

## Controller Changes

### SalaryEntriesController
- Add `require_authentication`
- Scope all queries to `current_user.salary_entries`
- Pre-fill hourly_rate from `current_user.default_hourly_rate`
- Update `yearly_summary` to scope to current user

## View Changes

### Layout
- Add header/navbar with:
  - App name
  - User's name when logged in
  - Logout button when logged in
  - Login/Signup links when logged out

### New Views (Tailwind styled)
- Login page
- Registration page

### Form Changes
- Pre-populate hourly_rate from user's default

## Testing

- User model specs (validations, associations)
- Registration request specs
- Session request specs (login/logout)
- Update salary_entries specs to include authentication
- Authorization specs (users can't access others' entries)

## Future Enhancements (out of scope)
- Household/shared view
- Password reset via email
- User profile editing
