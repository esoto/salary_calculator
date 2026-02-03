# Share via Link Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow budget owners to create shareable URLs that grant view-only access to external users.

**Architecture:** New `BudgetShare` model stores share tokens with visibility settings. Public controller serves read-only views. Owner-only controller manages share creation/deletion.

**Tech Stack:** Rails 8.1, TailwindCSS, Turbo/Stimulus

---

## Task 1: Create BudgetShare Model and Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_budget_shares.rb`
- Create: `app/models/budget_share.rb`
- Modify: `app/models/monthly_budget.rb`
- Create: `spec/models/budget_share_spec.rb`
- Create: `spec/factories/budget_shares.rb`

**Step 1: Write the failing model test**

```ruby
# spec/models/budget_share_spec.rb
require "rails_helper"

RSpec.describe BudgetShare, type: :model do
  describe "associations" do
    it { should belong_to(:monthly_budget) }
  end

  describe "validations" do
    it { should validate_presence_of(:token) }

    it "validates uniqueness of token" do
      create(:budget_share)
      should validate_uniqueness_of(:token)
    end
  end

  describe "token generation" do
    it "generates a token before creation" do
      budget = create(:monthly_budget)
      share = BudgetShare.create!(monthly_budget: budget)
      expect(share.token).to be_present
      expect(share.token.length).to be >= 32
    end
  end

  describe "#expired?" do
    let(:budget) { create(:monthly_budget) }

    it "returns false when expires_at is nil" do
      share = create(:budget_share, monthly_budget: budget, expires_at: nil)
      expect(share.expired?).to be false
    end

    it "returns false when expires_at is in the future" do
      share = create(:budget_share, monthly_budget: budget, expires_at: 1.day.from_now)
      expect(share.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      share = create(:budget_share, monthly_budget: budget, expires_at: 1.day.ago)
      expect(share.expired?).to be true
    end
  end

  describe "#display_name" do
    let(:budget) { create(:monthly_budget) }

    it "returns name when present" do
      share = create(:budget_share, monthly_budget: budget, name: "For accountant")
      expect(share.display_name).to eq("For accountant")
    end

    it "returns default when name is blank" do
      share = create(:budget_share, monthly_budget: budget, name: nil)
      expect(share.display_name).to eq("Share link ##{share.id}")
    end
  end

  describe ".active scope" do
    let(:budget) { create(:monthly_budget) }

    it "includes shares without expiration" do
      share = create(:budget_share, monthly_budget: budget, expires_at: nil)
      expect(BudgetShare.active).to include(share)
    end

    it "includes shares with future expiration" do
      share = create(:budget_share, monthly_budget: budget, expires_at: 1.day.from_now)
      expect(BudgetShare.active).to include(share)
    end

    it "excludes expired shares" do
      share = create(:budget_share, monthly_budget: budget, expires_at: 1.day.ago)
      expect(BudgetShare.active).not_to include(share)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/budget_share_spec.rb`
Expected: FAIL - uninitialized constant BudgetShare

**Step 3: Create migration**

```ruby
# db/migrate/TIMESTAMP_create_budget_shares.rb
class CreateBudgetShares < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_shares do |t|
      t.references :monthly_budget, null: false, foreign_key: true
      t.string :token, null: false
      t.string :name
      t.boolean :show_budget, default: true, null: false
      t.boolean :show_income_sources, default: false, null: false
      t.boolean :show_personal_savings, default: false, null: false
      t.datetime :expires_at

      t.timestamps
    end

    add_index :budget_shares, :token, unique: true
  end
end
```

**Step 4: Create model**

```ruby
# app/models/budget_share.rb
class BudgetShare < ApplicationRecord
  belongs_to :monthly_budget

  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def display_name
    name.presence || "Share link ##{id}"
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end
end
```

**Step 5: Create factory**

```ruby
# spec/factories/budget_shares.rb
FactoryBot.define do
  factory :budget_share do
    monthly_budget
    show_budget { true }
    show_income_sources { false }
    show_personal_savings { false }
    expires_at { nil }
  end
end
```

**Step 6: Add association to MonthlyBudget**

```ruby
# app/models/monthly_budget.rb - add after has_many :budget_items
has_many :budget_shares, dependent: :destroy
```

**Step 7: Run migration and tests**

Run: `bin/rails db:migrate && bundle exec rspec spec/models/budget_share_spec.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add BudgetShare model for shareable budget links"
```

---

## Task 2: Add Routes for Budget Shares

**Files:**
- Modify: `config/routes.rb`

**Step 1: Add routes**

```ruby
# config/routes.rb - add inside resources :budgets block
resources :budgets do
  resources :budget_shares, only: [:create, :destroy]
end

# Add public route outside authenticated section
get "shared/budgets/:token", to: "shared_budgets#show", as: :shared_budget
```

**Step 2: Verify routes**

Run: `bin/rails routes | grep -E "(budget_share|shared_budget)"`
Expected: Shows budget_shares and shared_budget routes

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add routes for budget sharing"
```

---

## Task 3: Create SharedBudgetsController (Public View)

**Files:**
- Create: `app/controllers/shared_budgets_controller.rb`
- Create: `app/views/shared_budgets/show.html.erb`
- Create: `app/views/shared_budgets/expired.html.erb`
- Create: `spec/requests/shared_budgets_spec.rb`

**Step 1: Write request tests**

```ruby
# spec/requests/shared_budgets_spec.rb
require "rails_helper"

RSpec.describe "SharedBudgets", type: :request do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  describe "GET /shared/budgets/:token" do
    context "with valid active share" do
      let!(:share) { create(:budget_share, monthly_budget: budget) }

      it "renders the shared budget view" do
        get shared_budget_path(share.token)
        expect(response).to have_http_status(:ok)
      end

      it "does not require authentication" do
        get shared_budget_path(share.token)
        expect(response).not_to redirect_to(new_session_path)
      end
    end

    context "with expired share" do
      let!(:share) { create(:budget_share, monthly_budget: budget, expires_at: 1.day.ago) }

      it "renders expired view" do
        get shared_budget_path(share.token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("expired")
      end
    end

    context "with invalid token" do
      it "returns 404" do
        get shared_budget_path("invalid-token")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/shared_budgets_spec.rb`
Expected: FAIL - uninitialized constant SharedBudgetsController

**Step 3: Create controller**

```ruby
# app/controllers/shared_budgets_controller.rb
class SharedBudgetsController < ApplicationController
  skip_before_action :require_authentication

  def show
    @share = BudgetShare.find_by(token: params[:token])

    if @share.nil?
      raise ActiveRecord::RecordNotFound
    elsif @share.expired?
      render :expired
    else
      @budget = @share.monthly_budget
      @income_sources = @budget.user.income_sources.active if @share.show_income_sources
      @salary_entry = @budget.user.salary_entries.find_by(year: @budget.year, month: @budget.month) if @share.show_personal_savings
    end
  end
end
```

**Step 4: Create show view**

```erb
<%# app/views/shared_budgets/show.html.erb %>
<div class="max-w-5xl mx-auto px-4 py-8">
  <!-- Header -->
  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
    <div class="flex items-center gap-2 text-blue-800">
      <span class="text-xl">🔗</span>
      <span class="font-medium">Shared Budget</span>
    </div>
    <p class="text-blue-700 mt-1">
      <%= Date::MONTHNAMES[@budget.month] %> <%= @budget.year %> • Shared by <%= @budget.user.name %>
    </p>
  </div>

  <% if @share.show_budget %>
    <!-- Summary Bar -->
    <div class="bg-white rounded-lg shadow p-4 mb-6">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
        <div>
          <span class="text-gray-500">Exchange Rate:</span>
          <span class="font-medium">₡<%= number_with_delimiter(@budget.exchange_rate.to_i) %>/$1</span>
        </div>
        <div>
          <span class="text-gray-500">Total Income:</span>
          <span class="font-medium text-green-600"><%= format_usd(@budget.total_income_usd) %></span>
        </div>
        <div>
          <span class="text-gray-500">Total Expenses:</span>
          <span class="font-medium"><%= format_usd(@budget.total_expenses_usd) %></span>
        </div>
        <div>
          <span class="text-gray-500">Remaining:</span>
          <% remaining = @budget.total_income_usd - @budget.total_expenses_usd %>
          <span class="font-medium <%= remaining >= 0 ? 'text-green-600' : 'text-red-600' %>">
            <%= format_usd(remaining) %>
          </span>
        </div>
      </div>
    </div>

    <!-- Category Columns (read-only) -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <% MonthlyBudget::CATEGORY_TARGETS.each_key do |category| %>
        <%= render "shared_budgets/category_column", budget: @budget, category: category %>
      <% end %>
    </div>
  <% end %>

  <% if @share.show_income_sources && @income_sources&.any? %>
    <!-- Income Sources Section -->
    <div class="bg-white rounded-lg shadow p-4 mb-6">
      <h3 class="text-lg font-semibold text-gray-800 mb-3">Income Sources</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <% @income_sources.each do |source| %>
          <div class="border border-gray-200 rounded-lg p-3">
            <div class="flex justify-between items-center">
              <span class="font-medium"><%= source.name %></span>
              <span class="text-green-600 font-medium">
                <% if source.usd? %>
                  <%= format_usd(source.amount_for_month(@budget.year, @budget.month)) %>
                <% else %>
                  <%= format_crc(source.amount_for_month(@budget.year, @budget.month)) %>
                <% end %>
              </span>
            </div>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>

  <% if @share.show_personal_savings && @salary_entry && has_any_savings?(@salary_entry) %>
    <!-- Personal Savings Section -->
    <div class="bg-white rounded-lg shadow p-4 mb-6">
      <h3 class="text-lg font-semibold text-gray-800 mb-3">Personal Savings</h3>
      <div class="flex flex-wrap items-center gap-x-6 gap-y-2 text-sm">
        <% if @salary_entry.user.aguinaldo_enabled %>
          <div>
            <span class="text-gray-500">Aguinaldo:</span>
            <span class="font-medium text-blue-600"><%= format_usd(@salary_entry.aguinaldo_savings) %></span>
          </div>
        <% end %>
        <% if @salary_entry.user.vacation_enabled %>
          <div>
            <span class="text-gray-500">Vacation:</span>
            <span class="font-medium text-blue-600"><%= format_usd(@salary_entry.vacation_savings) %></span>
          </div>
        <% end %>
        <% if @salary_entry.user.holiday_enabled %>
          <div>
            <span class="text-gray-500">Holiday:</span>
            <span class="font-medium text-blue-600"><%= format_usd(@salary_entry.holiday_savings) %></span>
          </div>
        <% end %>
        <div class="border-l border-gray-300 pl-6">
          <span class="text-gray-500">Total:</span>
          <span class="font-semibold text-blue-700"><%= format_usd(@salary_entry.monthly_savings_accrual) %></span>
        </div>
      </div>
    </div>
  <% end %>

  <!-- Footer -->
  <div class="bg-gray-50 rounded-lg p-4 text-center text-sm text-gray-600">
    <p>This is a read-only shared view.</p>
    <p class="mt-1">
      Want to create your own budgets?
      <%= link_to "Sign up", new_registration_path, class: "text-blue-600 hover:text-blue-800" %>
    </p>
  </div>
</div>
```

**Step 5: Create category column partial**

```erb
<%# app/views/shared_budgets/_category_column.html.erb %>
<div class="bg-white rounded-lg shadow">
  <div class="p-4 border-b border-gray-200">
    <div class="flex justify-between items-start">
      <div>
        <h3 class="font-semibold text-gray-800"><%= category_display_name(category) %></h3>
        <p class="text-xs text-gray-500">Target: <%= category_target_range(category) %></p>
      </div>
      <div class="text-right">
        <% status = budget.category_status(category) %>
        <span class="text-sm font-medium <%= category_status_color(status) %>">
          <%= category_status_icon(status) %> <%= budget.category_percentage(category) %>%
        </span>
        <p class="text-sm font-medium"><%= format_usd(budget.category_total_usd(category)) %></p>
      </div>
    </div>
  </div>

  <div class="p-4">
    <% budget.budget_items.where(category: category).order(:position).each do |item| %>
      <div class="flex justify-between items-center py-2 border-b border-gray-100 last:border-0">
        <span class="text-sm <%= item.paid? ? 'text-gray-400 line-through' : 'text-gray-700' %>">
          <%= item.name %>
        </span>
        <span class="text-sm font-medium">
          <%= item.usd? ? format_usd(item.amount) : format_crc(item.amount) %>
        </span>
      </div>
    <% end %>

    <% if budget.budget_items.where(category: category).empty? %>
      <p class="text-sm text-gray-400 text-center py-2">No items</p>
    <% end %>
  </div>
</div>
```

**Step 6: Create expired view**

```erb
<%# app/views/shared_budgets/expired.html.erb %>
<div class="max-w-md mx-auto px-4 py-16 text-center">
  <div class="bg-white rounded-lg shadow p-8">
    <div class="text-5xl mb-4">⏰</div>
    <h1 class="text-2xl font-bold text-gray-900 mb-2">Link Expired</h1>
    <p class="text-gray-600 mb-6">
      This share link is no longer valid.<br>
      Please contact the owner for a new link.
    </p>
    <%= link_to "Go to Salary Calculator", root_path,
        class: "inline-block bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg" %>
  </div>
</div>
```

**Step 7: Run tests**

Run: `bundle exec rspec spec/requests/shared_budgets_spec.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add public shared budget view"
```

---

## Task 4: Create BudgetSharesController (Management)

**Files:**
- Create: `app/controllers/budget_shares_controller.rb`
- Create: `spec/requests/budget_shares_spec.rb`

**Step 1: Write request tests**

```ruby
# spec/requests/budget_shares_spec.rb
require "rails_helper"

RSpec.describe "BudgetShares", type: :request do
  let(:user) { create(:user) }
  let(:budget) { create(:monthly_budget, user: user) }

  before { sign_in(user) }

  describe "POST /budgets/:budget_id/budget_shares" do
    let(:valid_params) do
      {
        budget_share: {
          name: "For accountant",
          show_budget: true,
          show_income_sources: true,
          show_personal_savings: false
        }
      }
    end

    it "creates a new share" do
      expect {
        post budget_budget_shares_path(budget), params: valid_params
      }.to change(BudgetShare, :count).by(1)
    end

    it "returns the share with token" do
      post budget_budget_shares_path(budget), params: valid_params, as: :turbo_stream
      expect(response).to have_http_status(:ok)
    end

    context "when not the budget owner" do
      let(:other_user) { create(:user) }
      before { sign_in(other_user) }

      it "denies access" do
        post budget_budget_shares_path(budget), params: valid_params
        expect(response).to redirect_to(budgets_path)
      end
    end
  end

  describe "DELETE /budget_shares/:id" do
    let!(:share) { create(:budget_share, monthly_budget: budget) }

    it "deletes the share" do
      expect {
        delete budget_share_path(share)
      }.to change(BudgetShare, :count).by(-1)
    end

    context "when not the budget owner" do
      let(:other_user) { create(:user) }
      before { sign_in(other_user) }

      it "denies access" do
        delete budget_share_path(share)
        expect(response).to redirect_to(budgets_path)
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/budget_shares_spec.rb`
Expected: FAIL - uninitialized constant BudgetSharesController

**Step 3: Create controller**

```ruby
# app/controllers/budget_shares_controller.rb
class BudgetSharesController < ApplicationController
  before_action :set_budget, only: [:create]
  before_action :set_budget_share, only: [:destroy]
  before_action :authorize_owner

  def create
    @share = @budget.budget_shares.build(share_params)

    if @share.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to budget_path(@budget), notice: "Share link created." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("share_form", partial: "budget_shares/form", locals: { budget: @budget, share: @share }) }
        format.html { redirect_to budget_path(@budget), alert: "Could not create share link." }
      end
    end
  end

  def destroy
    @budget = @share.monthly_budget
    @share.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to budget_path(@budget), notice: "Share link revoked." }
    end
  end

  private

  def set_budget
    @budget = MonthlyBudget.find(params[:budget_id])
  end

  def set_budget_share
    @share = BudgetShare.find(params[:id])
    @budget = @share.monthly_budget
  end

  def authorize_owner
    unless @budget.owned_by?(current_user)
      redirect_to budgets_path, alert: "Access denied."
    end
  end

  def share_params
    params.require(:budget_share).permit(:name, :show_budget, :show_income_sources, :show_personal_savings, :expires_at)
  end
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/requests/budget_shares_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add budget shares management controller"
```

---

## Task 5: Add Share UI to Budget Show Page

**Files:**
- Modify: `app/views/budgets/show.html.erb`
- Create: `app/views/budget_shares/_form.html.erb`
- Create: `app/views/budget_shares/_share.html.erb`
- Create: `app/views/budget_shares/_share_list.html.erb`
- Create: `app/views/budget_shares/create.turbo_stream.erb`
- Create: `app/views/budget_shares/destroy.turbo_stream.erb`
- Modify: `app/controllers/budgets_controller.rb`

**Step 1: Update budgets controller to load shares**

```ruby
# app/controllers/budgets_controller.rb - update show action
def show
  @income_sources = @budget.user.income_sources.active
  @salary_entry = @budget.user.salary_entries.find_by(year: @budget.year, month: @budget.month)
  @shares = @budget.budget_shares.order(created_at: :desc) if @budget.owned_by?(current_user)
  @new_share = @budget.budget_shares.build if @budget.owned_by?(current_user)
end
```

**Step 2: Add Share button and modal to budget show page**

Add after "Edit Settings" button in header:

```erb
<%# Add to app/views/budgets/show.html.erb header section, after Edit Settings link %>
<% if @budget.owned_by?(current_user) %>
  <button type="button"
          onclick="document.getElementById('share-modal').showModal()"
          class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
    Share
  </button>
<% end %>
```

Add modal and share list at bottom of file (before closing div):

```erb
<%# Add before closing </div> in app/views/budgets/show.html.erb %>

<% if @budget.owned_by?(current_user) %>
  <!-- Share Modal -->
  <dialog id="share-modal" class="rounded-lg shadow-xl p-0 backdrop:bg-black/50">
    <div class="p-6 w-96">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-bold">Share Budget</h2>
        <button onclick="document.getElementById('share-modal').close()" class="text-gray-400 hover:text-gray-600">✕</button>
      </div>
      <%= render "budget_shares/form", budget: @budget, share: @new_share %>
    </div>
  </dialog>

  <!-- Existing Shares -->
  <% if @shares.any? %>
    <div class="bg-white rounded-lg shadow mt-6 p-4" id="shares-list">
      <h3 class="text-lg font-semibold text-gray-800 mb-3">Shared Links</h3>
      <div class="divide-y divide-gray-100">
        <% @shares.each do |share| %>
          <%= render "budget_shares/share", share: share %>
        <% end %>
      </div>
    </div>
  <% end %>
<% end %>
```

**Step 3: Create share form partial**

```erb
<%# app/views/budget_shares/_form.html.erb %>
<%= form_with model: [budget, share], id: "share_form", data: { turbo_frame: "_top" } do |f| %>
  <div class="space-y-4">
    <div>
      <%= f.label :name, "Name (optional)", class: "block text-sm font-medium text-gray-700" %>
      <%= f.text_field :name, placeholder: "e.g., For accountant",
          class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500" %>
    </div>

    <fieldset>
      <legend class="text-sm font-medium text-gray-700 mb-2">Include in shared view:</legend>
      <div class="space-y-2">
        <label class="flex items-center">
          <%= f.check_box :show_budget, class: "rounded border-gray-300 text-blue-600 focus:ring-blue-500" %>
          <span class="ml-2 text-sm text-gray-600">Budget details (categories & items)</span>
        </label>
        <label class="flex items-center">
          <%= f.check_box :show_income_sources, class: "rounded border-gray-300 text-blue-600 focus:ring-blue-500" %>
          <span class="ml-2 text-sm text-gray-600">Income sources</span>
        </label>
        <label class="flex items-center">
          <%= f.check_box :show_personal_savings, class: "rounded border-gray-300 text-blue-600 focus:ring-blue-500" %>
          <span class="ml-2 text-sm text-gray-600">Personal savings</span>
        </label>
      </div>
    </fieldset>

    <div>
      <%= f.label :expires_at, "Expires (optional)", class: "block text-sm font-medium text-gray-700" %>
      <%= f.date_field :expires_at,
          class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500" %>
      <p class="mt-1 text-xs text-gray-500">Leave blank for no expiration</p>
    </div>

    <div class="flex justify-end gap-3 pt-4">
      <button type="button" onclick="document.getElementById('share-modal').close()"
              class="px-4 py-2 text-gray-600 hover:text-gray-800">
        Cancel
      </button>
      <%= f.submit "Create Share Link",
          class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg cursor-pointer" %>
    </div>
  </div>
<% end %>
```

**Step 4: Create share list item partial**

```erb
<%# app/views/budget_shares/_share.html.erb %>
<div class="py-3 flex items-center justify-between" id="<%= dom_id(share) %>">
  <div>
    <p class="font-medium text-gray-800"><%= share.display_name %></p>
    <p class="text-sm text-gray-500">
      Created <%= time_ago_in_words(share.created_at) %> ago
      <% if share.expires_at %>
        • Expires <%= share.expires_at.strftime("%b %d, %Y") %>
      <% end %>
    </p>
    <div class="flex items-center gap-2 mt-1">
      <input type="text" readonly value="<%= shared_budget_url(share.token) %>"
             class="text-xs bg-gray-100 px-2 py-1 rounded w-64 truncate" />
      <button onclick="navigator.clipboard.writeText('<%= shared_budget_url(share.token) %>')"
              class="text-xs text-blue-600 hover:text-blue-800">
        Copy
      </button>
    </div>
  </div>
  <%= button_to "Revoke", budget_share_path(share), method: :delete,
      class: "text-red-600 hover:text-red-800 text-sm",
      data: { turbo_confirm: "Revoke this share link?" } %>
</div>
```

**Step 5: Create turbo stream responses**

```erb
<%# app/views/budget_shares/create.turbo_stream.erb %>
<%= turbo_stream.prepend "shares-list" do %>
  <%= render "budget_shares/share", share: @share %>
<% end %>

<%= turbo_stream.replace "share_form" do %>
  <div class="text-center py-4">
    <p class="text-green-600 font-medium mb-2">Share link created!</p>
    <div class="flex items-center gap-2 justify-center">
      <input type="text" readonly value="<%= shared_budget_url(@share.token) %>"
             class="text-sm bg-gray-100 px-3 py-2 rounded w-72" />
      <button onclick="navigator.clipboard.writeText('<%= shared_budget_url(@share.token) %>')"
              class="text-blue-600 hover:text-blue-800 text-sm">
        Copy
      </button>
    </div>
    <button onclick="document.getElementById('share-modal').close()"
            class="mt-4 text-gray-600 hover:text-gray-800">
      Done
    </button>
  </div>
<% end %>
```

```erb
<%# app/views/budget_shares/destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@share) %>
```

**Step 6: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add share UI to budget show page"
```

---

## Task 6: Add System Tests for Share Flow

**Files:**
- Create: `spec/system/budget_sharing_spec.rb`

**Step 1: Write system tests**

```ruby
# spec/system/budget_sharing_spec.rb
require "rails_helper"

RSpec.describe "Budget Sharing", type: :system do
  let(:user) { create(:user) }
  let!(:budget) { create(:monthly_budget, user: user, year: 2026, month: 1) }

  before do
    driven_by(:rack_test)
  end

  describe "creating a share link" do
    before { sign_in(user) }

    it "shows share button on budget page" do
      visit budget_path(budget)
      expect(page).to have_button("Share")
    end

    it "creates a share link" do
      visit budget_path(budget)
      click_button "Share"

      fill_in "Name", with: "For accountant"
      check "Budget details"
      click_button "Create Share Link"

      expect(BudgetShare.count).to eq(1)
      expect(BudgetShare.last.name).to eq("For accountant")
    end
  end

  describe "viewing shared budget" do
    let!(:share) { create(:budget_share, monthly_budget: budget, show_budget: true) }

    it "shows budget without authentication" do
      visit shared_budget_path(share.token)

      expect(page).to have_content("Shared Budget")
      expect(page).to have_content("January 2026")
      expect(page).to have_content(user.name)
    end

    it "shows expired message for expired share" do
      share.update!(expires_at: 1.day.ago)

      visit shared_budget_path(share.token)

      expect(page).to have_content("Link Expired")
    end
  end

  describe "revoking a share link" do
    let!(:share) { create(:budget_share, monthly_budget: budget, name: "Test share") }

    before { sign_in(user) }

    it "removes the share link" do
      visit budget_path(budget)

      expect(page).to have_content("Test share")

      click_button "Revoke"

      expect(BudgetShare.count).to eq(0)
    end
  end
end
```

**Step 2: Run system tests**

Run: `bundle exec rspec spec/system/budget_sharing_spec.rb`
Expected: PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "test: add system tests for budget sharing flow"
```

---

## Task 7: Final Verification and Cleanup

**Step 1: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass, coverage >= 94%

**Step 2: Run linter**

Run: `bundle exec rubocop -A`
Expected: No offenses or auto-corrected

**Step 3: Verify in browser**

1. Start server: `bin/dev`
2. Log in and go to a budget
3. Click Share, create a link
4. Open link in incognito - should see read-only view
5. Revoke the link, verify it shows expired

**Step 4: Final commit if any changes**

```bash
git add -A
git commit -m "chore: final cleanup and lint fixes"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | BudgetShare model | model, migration, factory, tests |
| 2 | Routes | config/routes.rb |
| 3 | Public view controller | SharedBudgetsController, views |
| 4 | Management controller | BudgetSharesController |
| 5 | Share UI | budget show page, partials, turbo streams |
| 6 | System tests | spec/system/budget_sharing_spec.rb |
| 7 | Verification | full test run, linting |
