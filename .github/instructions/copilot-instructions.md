# GitHub Copilot Instructions for Pull Request Reviews

## Review Philosophy

- Only comment when you have HIGH CONFIDENCE (>80%) that an issue exists
- Be concise: one sentence per comment when possible
- Focus on actionable feedback, not observations
- When reviewing text, only comment on clarity issues if genuinely confusing

## Priority Areas (Review These)

### Security & Safety

- SQL injection risks (raw SQL with user input, missing parameterized queries)
- Mass assignment vulnerabilities (unpermitted params, missing strong parameters)
- Cross-site scripting (XSS) in views (missing `html_safe` justification, raw HTML)
- Authentication/authorization bypasses (missing `current_user` scoping)
- Credential exposure or hardcoded secrets
- Insecure direct object references (accessing records without ownership check)
- CSRF protection issues

### Correctness Issues

- Logic errors that could cause exceptions or incorrect behavior
- N+1 query problems (missing `includes`, `preload`, or `eager_load`)
- Race conditions in database operations (missing transactions, locks)
- Resource leaks (unclosed files, connections)
- Off-by-one errors or boundary conditions
- Nil handling issues (missing `&.` safe navigation, unhandled `nil`)
- Incorrect ActiveRecord callbacks order
- Missing validations for business rules

### Data Integrity

- User data not scoped to `current_user`
- Missing database constraints for model validations
- Uniqueness validations without corresponding database indexes
- Migrations that could fail on existing data
- Missing foreign key constraints

### Testing Gaps

- New features without corresponding tests
- Missing edge case coverage (nil, empty, boundary values)
- Tests that don't actually assert the behavior described
- Request specs missing authentication context
- Financial calculations without floating-point tolerance (`be_within`)

### Architecture & Patterns

- Business logic in controllers (should be in models/concerns)
- Code that violates existing patterns in the codebase
- Missing concerns for shared behavior across models
- Fat models that should be split into service objects
- Callbacks that should be explicit method calls

## File-Specific Guidelines

### Ruby Files (`*.rb`)

- Missing `# frozen_string_literal: true` pragma in new files
- Using `update_attribute` instead of `update` (skips validations)
- Raw SQL without parameterization
- Missing transaction blocks for multi-record operations

### Migration Files (`db/migrate/*.rb`)

- Missing `null: false` constraints for required fields
- Missing default values where appropriate
- Missing indexes for foreign keys and unique constraints
- Irreversible migrations without explicit `down` method

### View Files (`*.erb`, `*.html.erb`)

- Unescaped user content (XSS risk)
- Complex logic that belongs in helpers or presenters
- Hardcoded strings that should be in I18n

### Spec Files (`*_spec.rb`)

- Using `let!` when `let` would suffice
- Missing `context` blocks for different scenarios
- Brittle tests that depend on specific IDs or timestamps
- Tests without meaningful assertions

## Skip These (Low Value)

Do not comment on:

- Style/formatting (RuboCop handles this)
- Linter warnings (CI catches these)
- Minor naming suggestions
- Suggestions to add comments or documentation
- Refactoring unless addressing a real bug
- Missing logging unless security-related
- Pedantic suggestions about code organization
- Preferences that don't affect correctness or security

## Response Format

1. State the problem (1 sentence)
2. Why it matters (1 sentence, if needed)
3. Suggested fix (snippet or specific action)

**Example:**
```
User records are fetched without scoping to current_user. This allows users to access other users' data. Use `current_user.salary_entries.find(params[:id])` instead.
```

**Example:**
```
This query will cause N+1 issues when rendering the collection. Add `.includes(:user)` to the query.
```

## When to Stay Silent

If you're uncertain whether something is an issue, don't comment.
