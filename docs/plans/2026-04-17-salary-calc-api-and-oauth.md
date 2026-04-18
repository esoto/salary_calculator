# Salary Calc: API + OAuth for Expense Tracker Integration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expose the current month's `MonthlyBudget` over `/api/v1/` with Bearer token auth, and add a one-click OAuth-style linking flow so an external app (expense_tracker) can obtain a scoped, per-user token without manual copy-paste.

**Architecture:** New `ApiToken` model (user-scoped, BCrypt+SHA256 like expense_tracker's) authenticates API calls. New `OauthAuthorizationCode` model powers a short authorization-code flow: `/oauth/authorize` renders a consent page → creates a single-use code → `/oauth/token` exchanges code for token (server-to-server). Redirect URIs are validated against a hardcoded allowlist. No client registration, no public OAuth — this is a trusted first-party integration.

**Tech Stack:** Rails 8.1, PostgreSQL, RSpec, FactoryBot, BCrypt, existing `paper_trail` conventions.

**Scope boundary:** This plan covers ONLY the salary_calc side (steps 1–2 of the 4-step rollout). The expense_tracker side (callback, `ExternalBudgetSource`, `SyncService`, UI) gets its own plan in that repo.

**Design reference:** [`docs/plans/2026-04-17-salary-calc-expense-tracker-integration-design.md`](./2026-04-17-salary-calc-expense-tracker-integration-design.md)

---

## Conventions

- **Testing:** RSpec. Request specs use `sign_in(user)` helper from `spec/support/authentication_helpers.rb`. Factories in `spec/factories/`.
- **Migration timestamps:** use `bin/rails g migration <Name>` — it auto-timestamps. Current latest is `20260207...`.
- **Paper trail:** existing models use `has_paper_trail`. Do NOT add it to `ApiToken` or `OauthAuthorizationCode` — these are operational, not user-facing data.
- **Commits:** conventional commits, no `--no-verify`, one commit per task. Branch is already `claude/confident-gould-b16685`.
- **Running one spec file:** `bundle exec rspec spec/models/api_token_spec.rb`

---

## Phase A: Foundation (models + migrations)

### Task 1: `ApiToken` migration

**Files:**
- Create: `db/migrate/<timestamp>_create_api_tokens.rb`

**Step 1: Generate migration**

```bash
bin/rails g migration CreateApiTokens
```

**Step 2: Fill in the migration**

```ruby
class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_hash, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :active, null: false, default: true
      t.datetime :expires_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :api_tokens, :token_hash, unique: true
    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, [ :user_id, :active ]
  end
end
```

**Step 3: Run the migration**

```bash
bin/rails db:migrate
bin/rails db:migrate RAILS_ENV=test
```

Expected: both succeed. `schema.rb` gains the `api_tokens` table.

**Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add api_tokens table for API authentication"
```

---

### Task 2: `ApiToken` model + spec

**Files:**
- Create: `app/models/api_token.rb`
- Create: `spec/models/api_token_spec.rb`
- Create: `spec/factories/api_tokens.rb`
- Modify: `app/models/user.rb` (add `has_many :api_tokens`)

**Step 1: Write the failing spec**

```ruby
# spec/models/api_token_spec.rb
require "rails_helper"

RSpec.describe ApiToken do
  let(:user) { create(:user) }

  describe "validations" do
    it "requires a name" do
      token = ApiToken.new(user: user, name: nil)
      expect(token).not_to be_valid
      expect(token.errors[:name]).to include("can't be blank")
    end
  end

  describe "token generation" do
    it "generates a plaintext token, digest, and hash on create" do
      token = ApiToken.create!(user: user, name: "test")
      expect(token.token).to be_present
      expect(token.token_digest).to be_present
      expect(token.token_hash).to eq(Digest::SHA256.hexdigest(token.token))
    end

    it "exposes the plaintext token only on the in-memory instance, not reloaded" do
      token = ApiToken.create!(user: user, name: "test")
      plaintext = token.token
      expect(plaintext).to be_present
      expect(ApiToken.find(token.id).token).to be_nil
    end
  end

  describe ".authenticate" do
    let!(:token_record) { ApiToken.create!(user: user, name: "test") }
    let(:plaintext) { token_record.token }

    it "returns the token when the plaintext matches" do
      expect(ApiToken.authenticate(plaintext)).to eq(token_record)
    end

    it "returns nil for an unknown token" do
      expect(ApiToken.authenticate("not-a-real-token")).to be_nil
    end

    it "returns nil when the token is inactive" do
      token_record.update!(active: false)
      expect(ApiToken.authenticate(plaintext)).to be_nil
    end

    it "returns nil when the token is expired" do
      token_record.update!(expires_at: 1.minute.ago)
      expect(ApiToken.authenticate(plaintext)).to be_nil
    end

    it "touches last_used_at on successful authentication" do
      freeze_time do
        expect { ApiToken.authenticate(plaintext) }
          .to change { token_record.reload.last_used_at }.from(nil).to(Time.current)
      end
    end

    it "returns nil for blank input" do
      expect(ApiToken.authenticate(nil)).to be_nil
      expect(ApiToken.authenticate("")).to be_nil
    end
  end

  describe "#expired?" do
    it "is false when expires_at is nil" do
      expect(ApiToken.new(expires_at: nil)).not_to be_expired
    end

    it "is true when expires_at is past" do
      expect(ApiToken.new(expires_at: 1.minute.ago)).to be_expired
    end
  end

  describe "scopes column" do
    it "defaults to empty string" do
      token = ApiToken.create!(user: user, name: "test")
      expect(token.scopes).to eq("")
    end

    it "stores space-separated scopes" do
      token = ApiToken.create!(user: user, name: "test", scopes: "budget:read")
      expect(token.scope_list).to contain_exactly("budget:read")
    end
  end
end
```

**Step 2: Run spec to verify failure**

```bash
bundle exec rspec spec/models/api_token_spec.rb
```

Expected: all specs fail (model doesn't exist yet).

**Step 3: Write the factory**

```ruby
# spec/factories/api_tokens.rb
FactoryBot.define do
  factory :api_token do
    user
    name { "Test Token" }
  end
end
```

**Step 4: Write the model**

```ruby
# app/models/api_token.rb
require "digest"

class ApiToken < ApplicationRecord
  TOKEN_LENGTH = 32
  CACHE_KEY_LENGTH = 16
  CACHE_EXPIRY = 1.minute

  attr_accessor :token

  belongs_to :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_hash, presence: true, uniqueness: true
  validates :active, inclusion: { in: [ true, false ] }
  validate :expires_at_in_future, if: :expires_at?

  scope :active, -> { where(active: true) }
  scope :valid, -> { active.where("expires_at IS NULL OR expires_at > ?", Time.current) }

  before_validation :generate_token_if_blank, on: :create

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def valid_token?
    active? && !expired?
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def scope_list
    scopes.to_s.split(/\s+/).reject(&:blank?)
  end

  def has_scope?(scope)
    scope_list.include?(scope.to_s)
  end

  def self.authenticate(token_string)
    return nil if token_string.blank?

    cache_key = "api_token:#{Digest::SHA256.hexdigest(token_string)[0..CACHE_KEY_LENGTH]}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      token_hash = Digest::SHA256.hexdigest(token_string)
      api_token = valid.find_by(token_hash: token_hash)

      if api_token && BCrypt::Password.new(api_token.token_digest) == token_string
        api_token.touch_last_used!
        api_token
      end
    end
  end

  def self.generate_secure_token
    SecureRandom.urlsafe_base64(TOKEN_LENGTH)
  end

  private

  def generate_token_if_blank
    return if token_digest.present?

    self.token = self.class.generate_secure_token
    self.token_digest = BCrypt::Password.create(token)
    self.token_hash = Digest::SHA256.hexdigest(token)
  end

  def expires_at_in_future
    return unless expires_at.present?
    errors.add(:expires_at, "must be in the future") if expires_at <= Time.current
  end
end
```

**Step 5: Add association to `User`**

Modify `app/models/user.rb` — add after line 14 (`has_many :income_sources`):

```ruby
  has_many :api_tokens, dependent: :destroy
```

**Step 6: Run spec to verify pass**

```bash
bundle exec rspec spec/models/api_token_spec.rb
```

Expected: all green.

**Step 7: Commit**

```bash
git add app/models/api_token.rb app/models/user.rb spec/models/api_token_spec.rb spec/factories/api_tokens.rb
git commit -m "feat: add ApiToken model with BCrypt+SHA256 auth pattern"
```

---

### Task 3: `OauthAuthorizationCode` migration

**Files:**
- Create: `db/migrate/<timestamp>_create_oauth_authorization_codes.rb`

**Step 1: Generate migration**

```bash
bin/rails g migration CreateOauthAuthorizationCodes
```

**Step 2: Fill in the migration**

```ruby
class CreateOauthAuthorizationCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_authorization_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.string :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :oauth_authorization_codes, :code_digest, unique: true
    add_index :oauth_authorization_codes, :expires_at
  end
end
```

**Step 3: Migrate**

```bash
bin/rails db:migrate && bin/rails db:migrate RAILS_ENV=test
```

**Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add oauth_authorization_codes table"
```

---

### Task 4: `OauthAuthorizationCode` model + spec

**Files:**
- Create: `app/models/oauth_authorization_code.rb`
- Create: `spec/models/oauth_authorization_code_spec.rb`

**Step 1: Write the failing spec**

```ruby
# spec/models/oauth_authorization_code_spec.rb
require "rails_helper"

RSpec.describe OauthAuthorizationCode do
  let(:user) { create(:user) }

  describe ".issue" do
    it "creates a code, returns both the record and plaintext" do
      result = OauthAuthorizationCode.issue(
        user: user,
        redirect_uri: "https://example.test/cb",
        scopes: "budget:read"
      )

      expect(result.record).to be_persisted
      expect(result.plaintext).to be_present
      expect(result.record.code_digest).to eq(Digest::SHA256.hexdigest(result.plaintext))
      expect(result.record.expires_at).to be_within(2.seconds).of(60.seconds.from_now)
    end
  end

  describe ".consume" do
    let!(:issued) do
      OauthAuthorizationCode.issue(
        user: user,
        redirect_uri: "https://example.test/cb",
        scopes: "budget:read"
      )
    end

    it "returns the record and marks it used when valid" do
      record = OauthAuthorizationCode.consume(
        plaintext: issued.plaintext,
        redirect_uri: "https://example.test/cb"
      )

      expect(record).to eq(issued.record)
      expect(record.reload.used_at).to be_present
    end

    it "returns nil when already used" do
      OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://example.test/cb")
      second = OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://example.test/cb")
      expect(second).to be_nil
    end

    it "returns nil when expired" do
      issued.record.update!(expires_at: 1.second.ago)
      expect(
        OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://example.test/cb")
      ).to be_nil
    end

    it "returns nil when redirect_uri does not match" do
      expect(
        OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://other.test/cb")
      ).to be_nil
    end

    it "returns nil for unknown code" do
      expect(
        OauthAuthorizationCode.consume(plaintext: "not-real", redirect_uri: "https://example.test/cb")
      ).to be_nil
    end
  end
end
```

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/models/oauth_authorization_code_spec.rb
```

**Step 3: Write the model**

```ruby
# app/models/oauth_authorization_code.rb
require "digest"

class OauthAuthorizationCode < ApplicationRecord
  EXPIRATION = 60.seconds
  CODE_LENGTH = 32

  belongs_to :user

  validates :code_digest, presence: true, uniqueness: true
  validates :redirect_uri, presence: true
  validates :expires_at, presence: true

  IssueResult = Struct.new(:record, :plaintext, keyword_init: true)

  def self.issue(user:, redirect_uri:, scopes: "")
    plaintext = SecureRandom.urlsafe_base64(CODE_LENGTH)
    record = create!(
      user: user,
      code_digest: Digest::SHA256.hexdigest(plaintext),
      redirect_uri: redirect_uri,
      scopes: scopes,
      expires_at: EXPIRATION.from_now
    )
    IssueResult.new(record: record, plaintext: plaintext)
  end

  def self.consume(plaintext:, redirect_uri:)
    return nil if plaintext.blank?

    record = find_by(code_digest: Digest::SHA256.hexdigest(plaintext))
    return nil if record.nil?
    return nil if record.used_at.present?
    return nil if record.expires_at <= Time.current
    return nil if record.redirect_uri != redirect_uri

    record.update_column(:used_at, Time.current)
    record
  end
end
```

**Step 4: Run to verify pass**

```bash
bundle exec rspec spec/models/oauth_authorization_code_spec.rb
```

**Step 5: Commit**

```bash
git add app/models/oauth_authorization_code.rb spec/models/oauth_authorization_code_spec.rb
git commit -m "feat: add OauthAuthorizationCode for short-lived auth codes"
```

---

## Phase B: API endpoint

### Task 5: `Api::BaseController` with token auth

**Files:**
- Create: `app/controllers/api/base_controller.rb`
- Create: `spec/requests/api/base_controller_spec.rb`

**Step 1: Write the failing spec**

```ruby
# spec/requests/api/base_controller_spec.rb
require "rails_helper"

RSpec.describe "Api::BaseController auth", type: :request do
  # We'll exercise the base class via the monthly_budgets endpoint in Task 6.
  # This spec locks in the behavior of authenticate_token! directly by mounting a tiny test controller.

  controller_class = Class.new(Api::BaseController) do
    def show
      render json: { user_id: Current.user.id }
    end
  end

  before do
    stub_const("Api::AuthTestController", controller_class)
    Rails.application.routes.draw do
      namespace :api do
        get "auth_test", to: "auth_test#show"
      end
    end
  end

  after { Rails.application.reload_routes! }

  let(:user) { create(:user) }
  let(:api_token) { ApiToken.create!(user: user, name: "test", scopes: "budget:read") }
  let(:plaintext) { api_token.token }

  it "returns 401 when no Authorization header is provided" do
    get "/api/auth_test"
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq({ "error" => "unauthorized" })
  end

  it "returns 401 when the bearer token is invalid" do
    get "/api/auth_test", headers: { "Authorization" => "Bearer bogus" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "sets Current.user and responds 200 for a valid bearer token" do
    get "/api/auth_test", headers: { "Authorization" => "Bearer #{plaintext}" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq({ "user_id" => user.id })
  end
end
```

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/requests/api/base_controller_spec.rb
```

**Step 3: Write the controller**

```ruby
# app/controllers/api/base_controller.rb
module Api
  class BaseController < ActionController::API
    before_action :authenticate_token!

    attr_reader :current_api_token

    private

    def authenticate_token!
      token = bearer_token
      @current_api_token = ApiToken.authenticate(token)

      if @current_api_token
        Current.user_override = @current_api_token.user
      else
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end

    def bearer_token
      header = request.headers["Authorization"].to_s
      return nil unless header.start_with?("Bearer ")
      header.split(" ", 2).last
    end

    def require_scope!(scope)
      return if current_api_token&.has_scope?(scope)
      render json: { error: "insufficient_scope", required: scope }, status: :forbidden
    end
  end
end
```

**Step 4: Extend `Current` to support API-side user override**

Modify `app/models/current.rb`:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_override

  def user
    user_override || session&.user
  end
end
```

**Step 5: Run to verify pass**

```bash
bundle exec rspec spec/requests/api/base_controller_spec.rb
```

Also run the full existing session suite to make sure the `Current.user` change didn't break anything:

```bash
bundle exec rspec spec/requests/sessions_spec.rb spec/models/user_spec.rb
```

Expected: all green. If any of those fail, it means the `delegate :user, to: :session` removal broke something — re-examine.

**Step 6: Commit**

```bash
git add app/controllers/api/base_controller.rb app/models/current.rb spec/requests/api/base_controller_spec.rb
git commit -m "feat: add Api::BaseController with bearer-token authentication"
```

---

### Task 6: `Api::V1::MonthlyBudgetsController#current` — happy path

**Files:**
- Modify: `config/routes.rb` (add `namespace :api do namespace :v1 do ...`)
- Create: `app/controllers/api/v1/monthly_budgets_controller.rb`
- Create: `spec/requests/api/v1/monthly_budgets_spec.rb`

**Step 1: Write the failing spec (happy path only)**

```ruby
# spec/requests/api/v1/monthly_budgets_spec.rb
require "rails_helper"

RSpec.describe "Api::V1::MonthlyBudgets", type: :request do
  let(:user) { create(:user) }
  let(:api_token) { ApiToken.create!(user: user, name: "test", scopes: "budget:read") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.token}" } }

  describe "GET /api/v1/monthly_budgets/current" do
    it "returns 404 when no budget exists for the current month" do
      travel_to Date.new(2026, 4, 17) do
        get "/api/v1/monthly_budgets/current", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns the current month's budget with items" do
      travel_to Date.new(2026, 4, 17) do
        budget = MonthlyBudget.create!(user: user, year: 2026, month: 4, exchange_rate: 503)
        budget.budget_items.create!(name: "Rent", category: "fixed", amount: 800, currency: "USD", position: 1)
        budget.budget_items.create!(name: "Groceries", category: "guilt_free", amount: 300, currency: "USD", position: 2)

        get "/api/v1/monthly_budgets/current", headers: headers
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["monthly_budget"]).to include(
          "id" => budget.id,
          "year" => 2026,
          "month" => 4,
          "exchange_rate" => "503.0"
        )
        expect(body["budget_items"].size).to eq(2)
        expect(body["budget_items"].first).to include(
          "name" => "Rent",
          "category" => "fixed",
          "amount" => "800.0",
          "currency" => "USD"
        )
      end
    end

    it "only returns the authenticated user's budget" do
      travel_to Date.new(2026, 4, 17) do
        other_user = create(:user)
        MonthlyBudget.create!(user: other_user, year: 2026, month: 4, exchange_rate: 503)

        get "/api/v1/monthly_budgets/current", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
```

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/requests/api/v1/monthly_budgets_spec.rb
```

**Step 3: Add routes**

Modify `config/routes.rb` — add before `get "up" => ...`:

```ruby
  namespace :api do
    namespace :v1 do
      get "monthly_budgets/current", to: "monthly_budgets#current"
    end
  end
```

**Step 4: Write the controller**

```ruby
# app/controllers/api/v1/monthly_budgets_controller.rb
module Api
  module V1
    class MonthlyBudgetsController < Api::BaseController
      before_action -> { require_scope!("budget:read") }

      def current
        today = Date.current
        budget = Current.user.monthly_budgets.find_by(year: today.year, month: today.month)

        return render(json: { error: "not_found" }, status: :not_found) if budget.nil?

        render json: serialize(budget)
      end

      private

      def serialize(budget)
        {
          monthly_budget: {
            id: budget.id,
            year: budget.year,
            month: budget.month,
            exchange_rate: budget.exchange_rate.to_s,
            shared_with_household: budget.shared_with_household.present?,
            updated_at: budget.updated_at.iso8601
          },
          budget_items: budget.budget_items.ordered.map { |item| serialize_item(item) }
        }
      end

      def serialize_item(item)
        {
          id: item.id,
          name: item.name,
          category: item.category,
          amount: item.amount.to_s,
          currency: item.currency,
          position: item.position,
          paid: item.paid,
          updated_at: item.updated_at.iso8601
        }
      end
    end
  end
end
```

**Step 5: Run to verify pass**

```bash
bundle exec rspec spec/requests/api/v1/monthly_budgets_spec.rb
```

**Step 6: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/monthly_budgets_controller.rb spec/requests/api/v1/monthly_budgets_spec.rb
git commit -m "feat: expose GET /api/v1/monthly_budgets/current"
```

---

### Task 7: Add 401 + insufficient scope coverage

**Files:**
- Modify: `spec/requests/api/v1/monthly_budgets_spec.rb`

**Step 1: Add to the spec (append inside the `describe "GET ..."` block)**

```ruby
    it "returns 401 without a token" do
      travel_to Date.new(2026, 4, 17) do
        get "/api/v1/monthly_budgets/current"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "returns 403 when the token lacks the budget:read scope" do
      no_scope = ApiToken.create!(user: user, name: "limited", scopes: "")
      travel_to Date.new(2026, 4, 17) do
        get "/api/v1/monthly_budgets/current",
          headers: { "Authorization" => "Bearer #{no_scope.token}" }
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body["required"]).to eq("budget:read")
      end
    end
```

**Step 2: Run to verify pass**

No implementation changes needed — `require_scope!` and `authenticate_token!` already handle these.

```bash
bundle exec rspec spec/requests/api/v1/monthly_budgets_spec.rb
```

**Step 3: Commit**

```bash
git add spec/requests/api/v1/monthly_budgets_spec.rb
git commit -m "test: cover 401 and insufficient-scope cases on monthly_budgets#current"
```

---

### Task 8: `304 Not Modified` via `If-Modified-Since`

**Files:**
- Modify: `app/controllers/api/v1/monthly_budgets_controller.rb`
- Modify: `spec/requests/api/v1/monthly_budgets_spec.rb`

**Step 1: Add the failing test**

```ruby
    it "returns 304 when If-Modified-Since matches budget.updated_at" do
      travel_to Date.new(2026, 4, 17) do
        budget = MonthlyBudget.create!(user: user, year: 2026, month: 4, exchange_rate: 503)
        get "/api/v1/monthly_budgets/current",
          headers: headers.merge("If-Modified-Since" => budget.updated_at.httpdate)
        expect(response).to have_http_status(:not_modified)
      end
    end
```

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/requests/api/v1/monthly_budgets_spec.rb -e "304"
```

**Step 3: Update the controller**

Inside the `current` action, after the `return render(...not_found...)` line:

```ruby
        if stale?(last_modified: budget.updated_at, etag: budget.cache_key_with_version, public: false)
          render json: serialize(budget)
        end
```

Replace the existing `render json: serialize(budget)` with the block above.

**Step 4: Run to verify pass**

```bash
bundle exec rspec spec/requests/api/v1/monthly_budgets_spec.rb
```

**Step 5: Commit**

```bash
git add app/controllers/api/v1/monthly_budgets_controller.rb spec/requests/api/v1/monthly_budgets_spec.rb
git commit -m "feat: return 304 on monthly_budgets#current when unchanged"
```

---

## Phase C: OAuth flow

### Task 9: Redirect URI allowlist config

**Files:**
- Create: `config/initializers/oauth.rb`
- Modify: `config/credentials.yml.enc` (via `bin/rails credentials:edit`) OR use ENV — ENV is simpler

**Step 1: Create the initializer**

```ruby
# config/initializers/oauth.rb
Rails.application.config.x.oauth = ActiveSupport::OrderedOptions.new
Rails.application.config.x.oauth.redirect_uri_allowlist =
  ENV.fetch("OAUTH_REDIRECT_URI_ALLOWLIST", "").split(",").map(&:strip).reject(&:blank?)
```

**Step 2: Set dev defaults via `.env.development` (or equivalent)**

If the project uses `dotenv`, add to `.env.development`:

```
OAUTH_REDIRECT_URI_ALLOWLIST=http://localhost:3000/external_sources/callback,https://expense-tracker.estebansoto.dev/external_sources/callback
```

If no `dotenv` gem is present, document in README.md under "Environment variables" — but do not invent one; check `Gemfile`. If absent, skip setting dev defaults and let the OAuth tests stub the config directly (shown in Task 10).

**Step 3: Commit**

```bash
git add config/initializers/oauth.rb
git commit -m "feat: add OAuth redirect URI allowlist config"
```

---

### Task 10: `OAuth::AuthorizeController#show` (consent page)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/oauth/authorize_controller.rb`
- Create: `app/views/oauth/authorize/show.html.erb`
- Create: `spec/requests/oauth/authorize_spec.rb`

**Step 1: Write the failing spec (show action only)**

```ruby
# spec/requests/oauth/authorize_spec.rb
require "rails_helper"

RSpec.describe "OAuth Authorize", type: :request do
  let(:user) { create(:user) }
  let(:valid_redirect) { "https://expense-tracker.test/cb" }
  let(:state) { "client-state-123" }

  before do
    allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([ valid_redirect ])
  end

  describe "GET /oauth/authorize" do
    it "redirects to login when unauthenticated" do
      get "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      expect(response).to redirect_to(new_session_path)
    end

    it "renders the consent page when authenticated with a valid redirect_uri" do
      sign_in(user)
      get "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Expense Tracker")
      expect(response.body).to include("budget:read")
    end

    it "rejects redirect_uri not in the allowlist" do
      sign_in(user)
      get "/oauth/authorize", params: { redirect_uri: "https://evil.test/cb", state: state, scopes: "budget:read" }
      expect(response).to have_http_status(:bad_request)
    end

    it "requires a state parameter" do
      sign_in(user)
      get "/oauth/authorize", params: { redirect_uri: valid_redirect, scopes: "budget:read" }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
```

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/requests/oauth/authorize_spec.rb
```

**Step 3: Add the routes**

Modify `config/routes.rb` — before `namespace :api do`:

```ruby
  namespace :oauth do
    get "authorize", to: "authorize#show"
    post "authorize", to: "authorize#create"
    post "token", to: "token#create"
  end
```

**Step 4: Write the controller**

```ruby
# app/controllers/oauth/authorize_controller.rb
module Oauth
  class AuthorizeController < ApplicationController
    SUPPORTED_SCOPES = %w[budget:read].freeze

    before_action :validate_params!

    def show
      @redirect_uri = params[:redirect_uri]
      @state = params[:state]
      @requested_scopes = requested_scope_list
      render :show
    end

    def create
      # Task 11 fills this in
      head :not_implemented
    end

    private

    def validate_params!
      if params[:state].blank?
        render plain: "missing state", status: :bad_request and return
      end

      unless allowlisted_redirect?(params[:redirect_uri])
        render plain: "invalid redirect_uri", status: :bad_request and return
      end

      invalid_scopes = requested_scope_list - SUPPORTED_SCOPES
      if invalid_scopes.any?
        render plain: "unsupported scopes: #{invalid_scopes.join(',')}", status: :bad_request and return
      end
    end

    def allowlisted_redirect?(uri)
      Rails.application.config.x.oauth.redirect_uri_allowlist.include?(uri)
    end

    def requested_scope_list
      params[:scopes].to_s.split(/\s+/).reject(&:blank?)
    end
  end
end
```

**Step 5: Create the view**

```erb
<%# app/views/oauth/authorize/show.html.erb %>
<div class="max-w-md mx-auto mt-16 bg-white p-8 rounded-lg shadow">
  <h1 class="text-2xl font-bold mb-4">Authorize Expense Tracker</h1>

  <p class="mb-4 text-gray-700">
    <strong>Expense Tracker</strong> is requesting permission to access your salary calculator account.
  </p>

  <div class="bg-gray-50 p-4 rounded mb-6">
    <p class="font-medium mb-2">It will be able to:</p>
    <ul class="list-disc pl-6 text-sm text-gray-700">
      <% @requested_scopes.each do |scope| %>
        <% case scope %>
        <% when "budget:read" %>
          <li>Read your current monthly budget (plan + items)</li>
        <% else %>
          <li><%= scope %></li>
        <% end %>
      <% end %>
    </ul>
  </div>

  <%= form_with url: oauth_authorize_path, method: :post, local: true, class: "flex gap-3" do |f| %>
    <%= hidden_field_tag :redirect_uri, @redirect_uri %>
    <%= hidden_field_tag :state, @state %>
    <%= hidden_field_tag :scopes, @requested_scopes.join(" ") %>
    <%= submit_tag "Authorize", class: "bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700" %>
    <%= link_to "Cancel", dashboard_path, class: "bg-gray-200 text-gray-800 px-4 py-2 rounded hover:bg-gray-300" %>
  <% end %>
</div>
```

**Step 6: Run to verify pass**

```bash
bundle exec rspec spec/requests/oauth/authorize_spec.rb
```

**Step 7: Commit**

```bash
git add config/routes.rb app/controllers/oauth/authorize_controller.rb app/views/oauth/authorize/show.html.erb spec/requests/oauth/authorize_spec.rb
git commit -m "feat: add OAuth consent page (GET /oauth/authorize)"
```

---

### Task 11: `OAuth::AuthorizeController#create` (issue auth code, redirect)

**Files:**
- Modify: `app/controllers/oauth/authorize_controller.rb`
- Modify: `spec/requests/oauth/authorize_spec.rb`

**Step 1: Add the failing tests**

```ruby
  describe "POST /oauth/authorize" do
    before { sign_in(user) }

    it "issues an authorization code and redirects to redirect_uri with code + state" do
      expect {
        post "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      }.to change(OauthAuthorizationCode, :count).by(1)

      expect(response).to have_http_status(:redirect)
      location = URI.parse(response.headers["Location"])
      params_hash = Rack::Utils.parse_nested_query(location.query)
      expect(params_hash["state"]).to eq(state)
      expect(params_hash["code"]).to be_present
    end

    it "rejects an invalid redirect_uri" do
      post "/oauth/authorize", params: { redirect_uri: "https://evil.test/cb", state: state, scopes: "budget:read" }
      expect(response).to have_http_status(:bad_request)
    end

    it "requires authentication" do
      delete_session_cookie_or_sign_out
      post "/oauth/authorize", params: { redirect_uri: valid_redirect, state: state, scopes: "budget:read" }
      expect(response).to redirect_to(new_session_path)
    end
  end

  private

  def delete_session_cookie_or_sign_out
    cookies[:session_id] = nil
  end
```

(Note: append the `describe "POST"` block inside the same top-level describe as the GET tests. The `private` helper goes at the end of the file, outside all describes.)

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/requests/oauth/authorize_spec.rb
```

**Step 3: Replace the `create` action stub**

In `app/controllers/oauth/authorize_controller.rb`:

```ruby
    def create
      issued = OauthAuthorizationCode.issue(
        user: Current.user,
        redirect_uri: params[:redirect_uri],
        scopes: requested_scope_list.join(" ")
      )

      redirect_params = { code: issued.plaintext, state: params[:state] }
      redirect_to "#{params[:redirect_uri]}?#{redirect_params.to_query}",
                  allow_other_host: true
    end
```

**Step 4: Run to verify pass**

```bash
bundle exec rspec spec/requests/oauth/authorize_spec.rb
```

**Step 5: Commit**

```bash
git add app/controllers/oauth/authorize_controller.rb spec/requests/oauth/authorize_spec.rb
git commit -m "feat: POST /oauth/authorize issues auth code and redirects back"
```

---

### Task 12: `OAuth::TokenController#create` (exchange code for token)

**Files:**
- Create: `app/controllers/oauth/token_controller.rb`
- Create: `spec/requests/oauth/token_spec.rb`

**Step 1: Write the failing spec**

```ruby
# spec/requests/oauth/token_spec.rb
require "rails_helper"

RSpec.describe "OAuth Token", type: :request do
  let(:user) { create(:user) }
  let(:redirect_uri) { "https://expense-tracker.test/cb" }
  let!(:issued) do
    OauthAuthorizationCode.issue(user: user, redirect_uri: redirect_uri, scopes: "budget:read")
  end

  before do
    allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([ redirect_uri ])
  end

  describe "POST /oauth/token" do
    it "exchanges a valid code for an API token" do
      expect {
        post "/oauth/token",
             params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
             as: :json
      }.to change { ApiToken.count }.by(1)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["access_token"]).to be_present
      expect(body["token_type"]).to eq("Bearer")
      expect(body["scope"]).to eq("budget:read")

      expect(ApiToken.authenticate(body["access_token"])&.user).to eq(user)
    end

    it "rejects a reused code" do
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:ok)

      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a mismatched redirect_uri" do
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: "https://other.test/cb", grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects unsupported grant_type" do
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "password" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects redirect_uri not in allowlist" do
      allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([])
      post "/oauth/token",
           params: { code: issued.plaintext, redirect_uri: redirect_uri, grant_type: "authorization_code" },
           as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end
end
```

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/requests/oauth/token_spec.rb
```

**Step 3: Write the controller**

```ruby
# app/controllers/oauth/token_controller.rb
module Oauth
  class TokenController < ActionController::API
    def create
      return bad_request!("unsupported_grant_type") unless params[:grant_type] == "authorization_code"
      return bad_request!("invalid_redirect_uri") unless allowlisted_redirect?(params[:redirect_uri])

      record = OauthAuthorizationCode.consume(
        plaintext: params[:code],
        redirect_uri: params[:redirect_uri]
      )
      return bad_request!("invalid_grant") if record.nil?

      api_token = ApiToken.create!(
        user: record.user,
        name: "Expense Tracker (#{Date.current.iso8601})",
        scopes: record.scopes
      )

      render json: {
        access_token: api_token.token,
        token_type: "Bearer",
        scope: api_token.scopes
      }
    end

    private

    def allowlisted_redirect?(uri)
      Rails.application.config.x.oauth.redirect_uri_allowlist.include?(uri)
    end

    def bad_request!(reason)
      render json: { error: reason }, status: :bad_request
    end
  end
end
```

Route is already added in Task 10.

**Step 4: Run to verify pass**

```bash
bundle exec rspec spec/requests/oauth/token_spec.rb
```

**Step 5: Commit**

```bash
git add app/controllers/oauth/token_controller.rb spec/requests/oauth/token_spec.rb
git commit -m "feat: POST /oauth/token exchanges auth code for API token"
```

---

## Phase D: Connected Apps UI

### Task 13: `Settings → Connected Apps` index + revoke

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/connected_apps_controller.rb`
- Create: `app/views/connected_apps/index.html.erb`
- Create: `spec/requests/connected_apps_spec.rb`
- Modify: `app/views/settings/show.html.erb` (add a link to the page)

**Step 1: Write the failing spec**

```ruby
# spec/requests/connected_apps_spec.rb
require "rails_helper"

RSpec.describe "ConnectedApps", type: :request do
  let(:user) { create(:user) }
  let!(:token) { ApiToken.create!(user: user, name: "Expense Tracker", scopes: "budget:read") }

  before { sign_in(user) }

  describe "GET /connected_apps" do
    it "lists the user's active tokens" do
      get connected_apps_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Expense Tracker")
      expect(response.body).to include("budget:read")
    end

    it "does not list other users' tokens" do
      other = create(:user)
      ApiToken.create!(user: other, name: "Someone Else", scopes: "budget:read")
      get connected_apps_path
      expect(response.body).not_to include("Someone Else")
    end
  end

  describe "DELETE /connected_apps/:id" do
    it "revokes (deactivates) the token" do
      delete connected_app_path(token)
      expect(response).to redirect_to(connected_apps_path)
      expect(token.reload.active).to be false
    end

    it "rejects revoking another user's token" do
      other = create(:user)
      other_token = ApiToken.create!(user: other, name: "Theirs", scopes: "budget:read")
      delete connected_app_path(other_token)
      expect(response).to have_http_status(:not_found)
      expect(other_token.reload.active).to be true
    end
  end
end
```

**Step 2: Run to verify failure**

```bash
bundle exec rspec spec/requests/connected_apps_spec.rb
```

**Step 3: Add the route**

In `config/routes.rb`, alongside `resource :settings`:

```ruby
  resources :connected_apps, only: [ :index, :destroy ]
```

**Step 4: Write the controller**

```ruby
# app/controllers/connected_apps_controller.rb
class ConnectedAppsController < ApplicationController
  before_action :require_authentication

  def index
    @tokens = Current.user.api_tokens.active.order(created_at: :desc)
  end

  def destroy
    token = Current.user.api_tokens.find_by(id: params[:id])
    return head(:not_found) if token.nil?

    token.update!(active: false)
    redirect_to connected_apps_path, notice: "Token revoked."
  end
end
```

**Step 5: Write the view**

```erb
<%# app/views/connected_apps/index.html.erb %>
<div class="max-w-2xl mx-auto mt-8">
  <h1 class="text-2xl font-bold mb-6">Connected Apps</h1>

  <% if @tokens.any? %>
    <table class="min-w-full bg-white shadow rounded">
      <thead class="bg-gray-50">
        <tr>
          <th class="px-4 py-2 text-left">Name</th>
          <th class="px-4 py-2 text-left">Scopes</th>
          <th class="px-4 py-2 text-left">Last used</th>
          <th class="px-4 py-2"></th>
        </tr>
      </thead>
      <tbody>
        <% @tokens.each do |token| %>
          <tr class="border-t">
            <td class="px-4 py-2"><%= token.name %></td>
            <td class="px-4 py-2 text-sm text-gray-600"><%= token.scopes.presence || "—" %></td>
            <td class="px-4 py-2 text-sm text-gray-600">
              <%= token.last_used_at ? time_ago_in_words(token.last_used_at) + " ago" : "never" %>
            </td>
            <td class="px-4 py-2 text-right">
              <%= button_to "Revoke", connected_app_path(token),
                    method: :delete,
                    form: { data: { turbo_confirm: "Revoke this token?" } },
                    class: "text-red-600 hover:underline" %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  <% else %>
    <p class="text-gray-600">You have no connected apps.</p>
  <% end %>
</div>
```

**Step 6: Add a link from settings**

In `app/views/settings/show.html.erb`, add somewhere appropriate:

```erb
<%= link_to "Connected Apps", connected_apps_path, class: "text-blue-600 hover:underline" %>
```

(If the settings page has a sections/cards layout, match that style. Read the file first and pick the right spot.)

**Step 7: Run to verify pass**

```bash
bundle exec rspec spec/requests/connected_apps_spec.rb
```

**Step 8: Commit**

```bash
git add config/routes.rb app/controllers/connected_apps_controller.rb app/views/connected_apps/index.html.erb app/views/settings/show.html.erb spec/requests/connected_apps_spec.rb
git commit -m "feat: add Connected Apps settings page with revoke"
```

---

## Phase E: End-to-end validation

### Task 14: Full-flow integration spec

**Files:**
- Create: `spec/requests/oauth/full_flow_spec.rb`

**Step 1: Write the spec**

```ruby
# spec/requests/oauth/full_flow_spec.rb
require "rails_helper"

RSpec.describe "OAuth full flow", type: :request do
  let(:user) { create(:user) }
  let(:redirect_uri) { "https://expense-tracker.test/cb" }
  let(:state) { "state-abc" }

  before do
    allow(Rails.application.config.x.oauth).to receive(:redirect_uri_allowlist).and_return([ redirect_uri ])
    sign_in(user)
  end

  it "links salary_calc to an external app end-to-end" do
    # 1. External app redirects user to /oauth/authorize — consent page renders
    get "/oauth/authorize", params: { redirect_uri: redirect_uri, state: state, scopes: "budget:read" }
    expect(response).to have_http_status(:ok)

    # 2. User clicks Authorize — gets redirected back with code + state
    post "/oauth/authorize", params: { redirect_uri: redirect_uri, state: state, scopes: "budget:read" }
    expect(response).to have_http_status(:redirect)
    location = URI.parse(response.headers["Location"])
    query = Rack::Utils.parse_nested_query(location.query)
    expect(query["state"]).to eq(state)
    code = query["code"]

    # 3. External app exchanges the code for a token
    post "/oauth/token",
         params: { grant_type: "authorization_code", code: code, redirect_uri: redirect_uri },
         as: :json
    expect(response).to have_http_status(:ok)
    token = response.parsed_body["access_token"]
    expect(token).to be_present

    # 4. The token works against the API endpoint
    MonthlyBudget.create!(user: user, year: Date.current.year, month: Date.current.month, exchange_rate: 503)
    get "/api/v1/monthly_budgets/current", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("monthly_budget", "year")).to eq(Date.current.year)

    # 5. User revokes the token via Connected Apps
    api_token = ApiToken.find_by(token_hash: Digest::SHA256.hexdigest(token))
    delete connected_app_path(api_token)
    expect(api_token.reload.active).to be false

    # 6. Revoked token no longer authenticates
    get "/api/v1/monthly_budgets/current", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:unauthorized)
  end
end
```

**Step 2: Run it**

```bash
bundle exec rspec spec/requests/oauth/full_flow_spec.rb
```

Expected: pass (all pieces were built in prior tasks). If it fails, fix the offending piece before continuing.

**Step 3: Run the full test suite**

```bash
bundle exec rspec
```

Expected: all green. Fix any unrelated regressions.

**Step 4: Commit**

```bash
git add spec/requests/oauth/full_flow_spec.rb
git commit -m "test: end-to-end OAuth flow from authorize through API call + revoke"
```

---

### Task 15: RuboCop + Brakeman sweep

**Step 1: Run RuboCop**

```bash
bundle exec rubocop
```

Fix any offenses introduced by the new files. Common ones: missing `# frozen_string_literal: true`, trailing whitespace, incorrect indentation.

**Step 2: Run Brakeman**

```bash
bundle exec brakeman -q
```

Expected: no new warnings. Investigate anything added — especially around the redirect_to with `allow_other_host` in `authorize_controller.rb` (the allowlist check makes it safe, but Brakeman may flag it; confirm + document if so).

**Step 3: Commit any style fixes**

```bash
git add -u
git commit -m "chore: rubocop auto-fixes"
```

---

## Post-implementation

1. **Open the PR** against `develop` with title: `feat: API v1 + OAuth authorization for expense_tracker integration`. Reference the design doc.
2. **Manual smoke test** on the review environment:
   - Create a token manually in console, curl `/api/v1/monthly_budgets/current`, confirm 200.
   - Walk the full OAuth flow in a browser (use a local expense_tracker test server OR a throwaway script that receives the code and posts to `/oauth/token`).
3. **Next plan:** expense_tracker side. Separate repo, separate worktree, separate plan. Must cover: `ExternalBudgetSource` model, OAuth callback controller, `SyncService`, `PullJob`, Budget page display updates, category mapping UI, empty-state CTA.

---

## File summary

Created:
- `db/migrate/<ts>_create_api_tokens.rb`
- `db/migrate/<ts>_create_oauth_authorization_codes.rb`
- `app/models/api_token.rb`
- `app/models/oauth_authorization_code.rb`
- `app/controllers/api/base_controller.rb`
- `app/controllers/api/v1/monthly_budgets_controller.rb`
- `app/controllers/oauth/authorize_controller.rb`
- `app/controllers/oauth/token_controller.rb`
- `app/controllers/connected_apps_controller.rb`
- `app/views/oauth/authorize/show.html.erb`
- `app/views/connected_apps/index.html.erb`
- `config/initializers/oauth.rb`
- `spec/factories/api_tokens.rb`
- `spec/models/api_token_spec.rb`
- `spec/models/oauth_authorization_code_spec.rb`
- `spec/requests/api/base_controller_spec.rb`
- `spec/requests/api/v1/monthly_budgets_spec.rb`
- `spec/requests/oauth/authorize_spec.rb`
- `spec/requests/oauth/token_spec.rb`
- `spec/requests/oauth/full_flow_spec.rb`
- `spec/requests/connected_apps_spec.rb`

Modified:
- `app/models/user.rb` (has_many :api_tokens)
- `app/models/current.rb` (user_override)
- `config/routes.rb` (api namespace + oauth namespace + connected_apps)
- `app/views/settings/show.html.erb` (link to connected apps)
