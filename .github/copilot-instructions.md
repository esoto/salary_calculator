# Salary Calculator - AI Coding Instructions

## Project Overview
Rails 8.1 freelancer salary tracker with monthly entries, automatic savings calculations (aguinaldo, vacation, holidays), and time-off balance tracking. Uses SQLite with Solid Queue/Cache/Cable adapters.

## Architecture & Data Flow

### Core Domain Models
- **User**: Has configurable rates, vacation/holiday/aguinaldo toggles, and default settings
- **SalaryEntry**: Monthly records (unique per user/year/month) with `hours_worked`, `hourly_rate`, and time-off days taken
- **Session**: Cookie-based authentication (no Devise)
- **SalaryCalculations** concern: All monetary logic lives here - `monthly_salary`, `aguinaldo_savings`, `vacation_savings`, `holiday_savings`, `net_pay`

### Authentication Pattern
Uses custom authentication via `Authentication` concern:
- `Current.user` (ActiveSupport::CurrentAttributes) provides request-scoped user access
- Session stored in signed cookie, no tokens
- Controllers call `require_authentication` before_action
- Opt-out with `allow_unauthenticated_access` (e.g., `RegistrationsController`)

### Key Calculations (see [app/models/concerns/salary_calculations.rb](app/models/concerns/salary_calculations.rb))
- **Aguinaldo**: Monthly salary / 12 (1 month per year savings)
- **Vacation**: `(vacation_days_per_year * hours_per_day / 12) * hourly_rate`
- **Holiday**: Same formula as vacation
- **Net Pay**: `monthly_salary - (aguinaldo + vacation + holiday savings - days_taken_costs)`
- **Balance Validation**: Vacation days taken cannot exceed year-to-date earned (with override via `vacation_over_limit_acknowledged`)

## Development Workflow

### Setup & Running
```bash
bin/setup                    # Install deps, prepare DB
bin/dev                      # Runs Puma + Tailwind CSS watcher (foreman)
bin/rails server             # Server only
bin/rails tailwindcss:watch  # CSS only
```

### Testing with RSpec
```bash
bundle exec rspec                          # All specs
bundle exec rspec spec/models             # Models only
bundle exec rspec spec/requests           # Request specs
```
- Use FactoryBot (methods auto-included in `rails_helper.rb`)
- Default factory values: `hours_worked: 160.0, hourly_rate: 50.0`
- Shoulda matchers configured for associations/validations
- No controller test helpers - request specs test authentication flows

### Database Commands
```bash
bin/rails db:migrate
bin/rails db:reset           # Drop/create/load schema
bin/rails db:test:prepare
```

## Code Conventions

### Controller Patterns
1. **Authentication**: All controllers inherit `require_authentication` from `ApplicationController`
2. **Current User Access**: Use `current_user` (helper method exposing `Current.user`)
3. **Year Filtering**: Pattern is `@year = params[:year]&.to_i || Date.current.year`
4. **Vacation Balance**: Call `calculate_vacation_limit_status` in `new`/`edit`/`create`/`update` actions to set `@vacation_status` for warnings

### Model Patterns
1. **Scopes**: Use `ordered`, `for_year(year)`, `for_aguinaldo_period(year)` on `SalaryEntry`
2. **Validations**: Uniqueness on `[:month, :year, :user_id]`, numeric ranges (e.g., `month: 1..12, year: 2020..2100`)
3. **Concerns**: Extract shared calculations into concerns (e.g., `SalaryCalculations`)

### View & Styling
- **Tailwind CSS 4**: All styling via Tailwind utility classes
- **Turbo**: Enabled by default - use `data: { turbo_method: :delete, turbo_confirm: "..." }` for destructive actions
- **Chartkick**: Available for charts/graphs (gem already included)
- **Helpers**: Use `SalaryEntriesHelper` for `format_currency`, `format_hours`, `month_name`

### Migration & Schema
- SQLite production-ready (Rails 8 default)
- Decimal precision: `precision: 10, scale: 2` for currency, `precision: 4, scale: 2` for days
- Foreign keys enforced in schema

## Testing Practices
- **Model specs**: Validate associations, validations, and calculation methods
- **Request specs**: Test authentication flows and controller actions
- **Factories**: Create minimal valid records, override as needed
- **Test pattern**: `build(:salary_entry, hours_worked: 180)` for unsaved, `create(:user)` for persisted

## Code Review Behavior
- **Only comment when 100% confident**: If you are not absolutely certain about an issue, do not add a comment. Stay silent rather than provide uncertain or speculative feedback.
- **Avoid false positives**: Verify your understanding of the code before flagging issues. Check if the code you're reviewing has already been updated or if you're looking at stale context.
- **No speculative suggestions**: Do not suggest changes based on assumptions. If you need to see more context to be confident, do not comment.

## Critical Non-Obvious Details
1. **Vacation Balance Logic** ([app/models/user.rb#L22-29](app/models/user.rb#L22-29)): Accrued monthly as `entries_count * (vacation_days_per_year / 12)`, compared against `sum(:vacation_days_taken)`. Edit/new forms exclude the current entry from balance check.
2. **Aguinaldo Calculation**: Simple 1/12th monthly accrual, not tied to specific period (user sets toggle)
3. **Settings Page**: User can toggle aguinaldo/vacation/holiday independently and set default hourly rate
4. **Vacation Override**: When user tries to take more vacation than accrued, they must acknowledge via `vacation_over_limit_acknowledged` attribute

## Future Features Reference
See [docs/PENDING_FEATURES.md](docs/PENDING_FEATURES.md) for planned work:
- Multiple entries per month (multi-client support)
- Vacation carryover to next year
- Calendar view for time-off dates
- Household/shared views

## Files to Check First
- [app/models/concerns/salary_calculations.rb](app/models/concerns/salary_calculations.rb) - All monetary logic
- [app/controllers/concerns/authentication.rb](app/controllers/concerns/authentication.rb) - Auth pattern
- [app/models/user.rb](app/models/user.rb) - User settings and vacation balance
- [spec/models/salary_entry_spec.rb](spec/models/salary_entry_spec.rb) - Comprehensive calculation examples
