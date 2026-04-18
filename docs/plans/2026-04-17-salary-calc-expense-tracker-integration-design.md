# Salary Calculator ↔ Expense Tracker Integration Design

**Date:** 2026-04-17
**Status:** Design approved, ready to plan implementation
**Phase:** 1 (basic integration; foundation for future consolidation into a single app with engines)

## Context

Two separate Rails apps currently exist:

- **salary_calculator** (Rails 8.1) — income tracking, Mexican-labor-law savings calculations, `MonthlyBudget` with `BudgetItem`s (`fixed` / `guilt_free` / `savings` / `investments`). Session-based auth, household sharing. No API.
- **expense_tracker** (Rails 8.0.2) — bank email parsing, hierarchical `Category` taxonomy, `Budget` model scoped to `email_account` with period-based `current_spend` aggregation. Has `ApiToken` model and `/api/v1/` namespace already. No User model.

Goal: connect salary_calc's monthly budget to expense_tracker's budget section so the user sees planned-vs-actual in the app they already check daily. Long-term vision is a single "personal finance OS" app with engines, but phase 1 is an integration between two independent apps. Every decision below is chosen to be **merge-compatible** — when the apps consolidate, no hot-path rewrite is required.

Income source syncing and graphs are explicitly deferred to a later phase.

## Direction

Salary_calc is the **source** (budget plan). Expense_tracker is the **consumer**. Expense_tracker's existing `Budget` pattern (expense → category → budget via `category_id`) is reused as-is — synced salary_calc items become local `Budget` rows that track spend through the existing `calculate_current_spend!` machinery.

## Data model

### salary_calculator (source side)

New `ApiToken` model, shape mirrors expense_tracker's:

- `user_id` (FK — token is scoped to a user)
- `name` (e.g. `"Expense Tracker"`)
- `token_digest` (BCrypt)
- `token_hash` (SHA256, for fast lookup)
- `scopes` (string, e.g. `"budget:read"`)
- `active` (boolean)
- `expires_at`, `last_used_at` (timestamps)

New `OauthAuthorizationCode` model (short-lived, single-use):

- `user_id`, `code_digest` (SHA256)
- `redirect_uri`, `scopes`, `expires_at` (60 seconds)
- `used_at` (nullable — flips on exchange, enforces single-use)

No changes to `MonthlyBudget`, `BudgetItem`, `IncomeSource`, etc.

### expense_tracker (consumer side)

Add nullable columns to `Budget`:

- `external_source` (string, e.g. `"salary_calculator"`)
- `external_id` (integer — the remote `BudgetItem.id`)
- `external_synced_at` (timestamp)

A Budget row with these fields set is a mirror of a salary_calc budget item. User's `category_id` mapping lives on the same row.

New `ExternalBudgetSource` model (one per `email_account`):

- `email_account_id` (FK)
- `source_type` (string, for now always `"salary_calculator"`)
- `base_url` (string)
- `api_token` (encrypted via Rails `encrypts`)
- `last_synced_at`, `last_sync_status`, `last_sync_error`
- `active` (boolean)

No changes to `Expense` or `Category`.

### Merge-compat

When the apps consolidate:

- `external_source` / `external_id` → replaced by a direct `budget_item_id` FK.
- `ExternalBudgetSource` → deleted.
- `ApiToken` / `OauthAuthorizationCode` / consent page → deleted.
- Existing synced `Budget` rows stay — their `current_spend` cache survives.

No hot-path code (sync, aggregation, display) needs rewriting.

## API contract

New namespace on salary_calc: `/api/v1/`. Authentication via `Authorization: Bearer <token>`.

### `GET /api/v1/monthly_budgets/current`

Returns the current month's budget plan for the token's owning user.

```json
{
  "monthly_budget": {
    "id": 42,
    "year": 2026, "month": 4,
    "exchange_rate": "503.0",
    "shared_with_household": true,
    "updated_at": "2026-04-17T15:00:00Z"
  },
  "budget_items": [
    {
      "id": 101,
      "name": "Rent",
      "category": "fixed",
      "amount": "800.00",
      "currency": "USD",
      "position": 1,
      "paid": false,
      "updated_at": "2026-04-15T10:00:00Z"
    }
  ]
}
```

**Responses:**

- `200` — budget found and returned
- `304 Not Modified` — via `If-Modified-Since` against `monthly_budget.updated_at` (skips redundant syncs)
- `401` — token missing, invalid, or expired
- `404` — no `MonthlyBudget` for the current year/month

**Controller base class:** `Api::BaseController#authenticate_token!` calls `ApiToken.authenticate(token)` (BCrypt + SHA256 cache pattern), sets `Current.user`. Mirrors expense_tracker's existing auth layer.

**Explicitly out of scope for phase 1:**

- Write endpoints (expense_tracker is strictly read-only against salary_calc).
- Historical months endpoint.
- Household-member-level income breakdown.
- Income sources endpoint.

## Account linking (OAuth-style)

Manual token paste was rejected. The flow must be one-click from the user's perspective while staying scoped to a specific salary_calc user.

### Flow

1. **Expense_tracker:** user clicks `[Connect salary_calc]` in `Settings → External Sources`. Server generates a random `state`, stores it tied to `email_account_id`, expires in 10 minutes.
2. **Redirect:** browser → `https://salary-calc.estebansoto.dev/oauth/authorize?redirect_uri=<expense_tracker callback>&state=<state>&scopes=budget:read`.
3. **Salary_calc:** if no session, enforce login first. Then render a consent page: *"Expense Tracker wants to read your monthly budget. [Authorize] [Cancel]"*.
4. **On Authorize:** salary_calc validates `redirect_uri` against a hardcoded allowlist. Creates `OauthAuthorizationCode` for `Current.user`. Redirects to `<redirect_uri>?state=<state>&code=<auth code>`.
5. **Expense_tracker callback:** verifies `state` matches a stored pending link. Server-to-server POSTs `code` to `https://salary-calc.estebansoto.dev/oauth/token`. Receives back a real `ApiToken`. Saves it (encrypted) in `ExternalBudgetSource`. Deletes the state. First sync fires immediately.
6. **Redirect** to expense_tracker settings with `"✓ Connected to salary_calc"`.

### Security guardrails

- **Redirect URI allowlist** — hardcoded in salary_calc (env-configured per environment). Prevents a malicious site from tricking salary_calc into leaking tokens.
- **State parameter** — expense_tracker stores it server-side; callback rejects if mismatched. Blocks CSRF.
- **Auth codes** — single-use (enforced by `used_at`), expire in 60 seconds, SHA256-digested at rest.
- **Token never in browser URL** — only the auth code traverses the browser. Real token stays server-to-server.
- **Scopes** — phase 1 only issues `budget:read`. Adding scopes later is additive and non-breaking.

### Unlink flow

Two places, both must be shown to the user:

- **expense_tracker** → `Settings → External Sources → Disconnect` — deletes `ExternalBudgetSource`, stops syncing locally. Synced Budgets go inactive.
- **salary_calc** → `Settings → Connected Apps → Revoke` — revokes the `ApiToken`. Forces re-auth even if the token was copied elsewhere.

## Category mapping

Synced Budgets arrive with `category_id: nil`. User sets it manually in expense_tracker, one category per synced Budget. 1:1 mapping for phase 1.

`Budget.calculate_current_spend!` only runs when both `external_source` is set AND `category_id` is present. Unmapped synced Budgets show a yellow banner in the UI with an inline category picker.

Phase 2 (deferred): auto-suggest mappings using the existing `Categorization::Engine` — seed from the mapping table the user built in phase 1.

## Sync mechanics

**Trigger:**

- "Sync now" button in `Settings → External Sources` (enqueues the job immediately).
- Background job scheduled daily via Solid Queue cron.

**Service:** `ExternalBudgets::SyncService#call(external_budget_source)`.

**Job:** `ExternalBudgets::PullJob` wraps the service.

**Logic:**

1. Call `GET /api/v1/monthly_budgets/current` with the stored token.
2. For each `budget_item` in response:
   - Find local `Budget` by `(external_source: "salary_calculator", external_id: item.id)`.
   - If found → update `name`, `amount`, `currency`. Preserve user's `category_id`.
   - If not found → create with those fields + `category_id: nil`.
3. Budgets previously synced but not in the current response → `active: false` (don't delete; preserves history).
4. Update `last_synced_at` / `last_sync_status` on `ExternalBudgetSource`.

**Month rollover:** when `year/month` in response differs from locally stored values, previous month's synced Budgets stay as historical rows (still `active: false` per step 3). New month's items become new active rows. Each month has its own set of external Budgets.

**Error handling:**

- `401` → mark source inactive, surface *"Reconnect required"* banner in UI.
- `5xx` / network error → exponential backoff, max 3 attempts.
- `404` (no MonthlyBudget for current month) → record `last_synced_at`, succeed silently.

## UI touchpoints

### salary_calc

- `Settings → Connected Apps` — table of active `ApiToken`s: name, scopes, created, last used. One-click Revoke per row.
- `GET /oauth/authorize` — consent page. Simple, shows requested scope.
- No changes to existing budget/dashboard pages.

### expense_tracker

- `Settings → External Sources` — connection card:
  - Not connected: *"Not connected"* + `[Connect salary_calc]`.
  - Connected: *"Connected • last synced 2m ago"* + `[Sync now]` + `[Disconnect]`.
  - Reconnect required (token expired): yellow banner + `[Reconnect]`.
- `Budgets` page:
  - Synced Budgets get a `"from salary_calc"` badge.
  - Unmapped synced Budgets show a yellow banner: *"Pick a category to start tracking spend"* with an inline category picker.
  - Once mapped, render identically to native Budgets — existing current_spend, status, thresholds all work unchanged.
- **Empty state when not connected:** replace the Budget list with *"Connect salary_calc to pull in your monthly budget"* CTA (per user preference — don't show native Budget CRUD while unlinked).

## Testing strategy

### salary_calc

- Request specs for `/api/v1/monthly_budgets/current`: happy path, 401 (missing/invalid/expired token), 404 (no budget for month), 304 (If-Modified-Since).
- Request specs for OAuth flow: `/oauth/authorize` (login-gated, consent page, allowlist validation), `/oauth/token` (valid code, expired code, reused code, mismatched redirect_uri).
- System spec for consent page rendering + Authorize click → redirect.
- System spec for Connected Apps page → Revoke flow.

### expense_tracker

- Service spec for `SyncService`: create / update / deactivate / preserve-mapping paths, all error branches.
- WebMock stubs for the salary_calc API — no live HTTP in tests.
- Request spec for OAuth callback: state verification, code-for-token exchange, error surfaces.
- System spec for end-to-end link flow (stubbed external).
- Request spec for `Budget` display: unmapped badge, mapped display, spend calculation runs only when mapped.

## Rollout order

Each step is independently shippable and testable:

1. **Salary_calc API + auth** — `ApiToken` model, `/api/v1/monthly_budgets/current`, token authentication. Verifiable via `curl` with a manually-seeded token.
2. **Salary_calc OAuth** — `/oauth/authorize`, `/oauth/token`, `OauthAuthorizationCode` model, consent page, Connected Apps UI.
3. **Expense_tracker linking** — `ExternalBudgetSource` model, OAuth callback, connection UI in `Settings → External Sources`.
4. **Expense_tracker sync + display** — `SyncService`, `PullJob`, Budget page changes, category mapping UI, empty-state CTA.

## Phase 2 (deferred)

- Auto-suggest category mappings via `Categorization::Engine`.
- Income sources endpoint + dashboard widgets (planned vs actual income).
- Graphs: spend trend per budget item across months.
- Webhook from salary_calc → expense_tracker for push updates when a BudgetItem changes.
- Multi-email_account support (one salary_calc plan mirrored into multiple email_accounts).

## Explicitly out of scope forever (by design)

- Write access from expense_tracker to salary_calc.
- Multi-user OAuth (public client registration). Hardcoded redirect_uri allowlist is fine for personal use.
- Income source breakdowns per household member.
