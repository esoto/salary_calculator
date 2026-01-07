# User Authentication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add user accounts with Rails 8 authentication so each user has private salary entries.

**Architecture:** Use Rails 8 `rails generate authentication` for base auth, add custom User fields (name, default_hourly_rate), create RegistrationsController for signup, scope SalaryEntry to current_user.

**Tech Stack:** Rails 8, bcrypt, RSpec, FactoryBot, Shoulda Matchers, Tailwind CSS v4

---

## Task 1: Run Rails 8 Authentication Generator

**Files:**
- Create: `app/models/user.rb`
- Create: `app/models/session.rb`
- Create: `app/models/current.rb`
- Create: `app/controllers/sessions_controller.rb`
- Create: `app/controllers/passwords_controller.rb`
- Create: `app/controllers/concerns/authentication.rb`
- Create: `app/views/sessions/new.html.erb`
- Create: `app/views/passwords/new.html.erb`
- Create: `app/views/passwords/edit.html.erb`
- Create: `db/migrate/*_create_users.rb`
- Create: `db/migrate/*_create_sessions.rb`

**Step 1: Run the authentication generator**

Run: `rails generate authentication`

**Step 2: Run migrations**

Run: `rails db:migrate`

**Step 3: Verify generator created files**

Run: `ls app/models/user.rb app/controllers/sessions_controller.rb app/controllers/concerns/authentication.rb`
Expected: Files exist

**Step 4: Commit**

```bash
git add -A
git commit -m "Run Rails 8 authentication generator"
```

---

## Task 2: Add Custom User Fields

**Files:**
- Create: `db/migrate/*_add_fields_to_users.rb`
- Modify: `app/models/user.rb`
- Create: `spec/models/user_spec.rb`
- Create: `spec/factories/users.rb`

**Step 1: Create factory for users**

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }
    name { "Test User" }
    default_hourly_rate { 50.0 }
  end
end
```

**Step 2: Write failing tests for User validations**

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email_address) }
    it { should validate_uniqueness_of(:email_address).case_insensitive }
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:default_hourly_rate).is_greater_than(0).allow_nil }
  end

  describe 'associations' do
    it { should have_many(:salary_entries).dependent(:destroy) }
  end
end
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: FAIL - name validation missing, association missing

**Step 4: Generate migration for custom fields**

Run: `rails generate migration AddFieldsToUsers name:string default_hourly_rate:decimal`

**Step 5: Update migration with constraints**

```ruby
# db/migrate/*_add_fields_to_users.rb
class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string, null: false
    add_column :users, :default_hourly_rate, :decimal, precision: 10, scale: 2
  end
end
```

**Step 6: Run migration**

Run: `rails db:migrate`

**Step 7: Update User model with validations and association**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :salary_entries, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :default_hourly_rate, numericality: { greater_than: 0 }, allow_nil: true
end
```

**Step 8: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: All PASS

**Step 9: Commit**

```bash
git add -A
git commit -m "Add name and default_hourly_rate to User"
```

---

## Task 3: Associate SalaryEntry with User

**Files:**
- Create: `db/migrate/*_add_user_to_salary_entries.rb`
- Modify: `app/models/salary_entry.rb`
- Modify: `spec/models/salary_entry_spec.rb`
- Modify: `spec/factories/salary_entries.rb`

**Step 1: Update factory to include user**

```ruby
# spec/factories/salary_entries.rb
FactoryBot.define do
  factory :salary_entry do
    user
    month { 1 }
    year { 2025 }
    hours_worked { 160.0 }
    hourly_rate { 50.0 }
  end
end
```

**Step 2: Add failing test for user association**

Add to `spec/models/salary_entry_spec.rb` in validations block:

```ruby
it { should belong_to(:user) }
```

Update uniqueness test:

```ruby
it { should validate_uniqueness_of(:month).scoped_to(:year, :user_id) }
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - association missing

**Step 4: Generate migration**

Run: `rails generate migration AddUserToSalaryEntries user:references`

**Step 5: Update migration**

```ruby
# db/migrate/*_add_user_to_salary_entries.rb
class AddUserToSalaryEntries < ActiveRecord::Migration[8.0]
  def change
    add_reference :salary_entries, :user, null: false, foreign_key: true

    # Update unique index to include user_id
    remove_index :salary_entries, [:month, :year]
    add_index :salary_entries, [:month, :year, :user_id], unique: true
  end
end
```

**Step 6: Create a temporary user for existing entries (if any)**

Run: `rails db:migrate`

Note: If migration fails due to existing entries without user_id, you may need to either:
- Delete existing entries: `rails runner "SalaryEntry.delete_all"`
- Or modify migration to create a default user first

**Step 7: Update SalaryEntry model**

```ruby
# app/models/salary_entry.rb
class SalaryEntry < ApplicationRecord
  include SalaryCalculations

  belongs_to :user

  scope :for_year, ->(year) { where(year: year) }
  scope :ordered, -> { order(:year, :month) }

  validates :month, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :hours_worked, presence: true,
                           numericality: { greater_than: 0 }
  validates :hourly_rate, presence: true,
                          numericality: { greater_than: 0 }
  validates :month, uniqueness: { scope: [:year, :user_id] }

  def self.yearly_summary(year)
    entries = for_year(year)

    {
      total_earnings: entries.sum(&:monthly_salary),
      total_aguinaldo: entries.sum(&:aguinaldo_savings),
      total_vacation: entries.sum(&:vacation_savings),
      total_holidays: entries.sum(&:holiday_savings),
      total_savings: entries.sum(&:total_savings),
      entries_count: entries.count
    }
  end
end
```

**Step 8: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: All PASS

**Step 9: Commit**

```bash
git add -A
git commit -m "Associate SalaryEntry with User"
```

---

## Task 4: Create RegistrationsController

**Files:**
- Create: `app/controllers/registrations_controller.rb`
- Create: `app/views/registrations/new.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/requests/registrations_spec.rb`

**Step 1: Write failing request specs**

```ruby
# spec/requests/registrations_spec.rb
require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "GET /registrations/new" do
    it "returns success" do
      get new_registration_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /registrations" do
    let(:valid_params) do
      {
        user: {
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "Test User",
          default_hourly_rate: 50
        }
      }
    end

    it "creates a new user" do
      expect {
        post registrations_path, params: valid_params
      }.to change(User, :count).by(1)
    end

    it "logs in the user and redirects to salary entries" do
      post registrations_path, params: valid_params
      expect(response).to redirect_to(salary_entries_path)
    end

    context "with invalid params" do
      it "does not create user with missing name" do
        expect {
          post registrations_path, params: { user: valid_params[:user].except(:name) }
        }.not_to change(User, :count)
      end
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/registrations_spec.rb`
Expected: FAIL - routes don't exist

**Step 3: Add routes**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [:new, :create]

  resources :salary_entries do
    collection do
      get :summary
    end
  end

  root "salary_entries#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
```

**Step 4: Create controller**

```ruby
# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for(@user)
      redirect_to salary_entries_path, notice: "Welcome! Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :name, :default_hourly_rate)
  end
end
```

**Step 5: Create registration view**

```erb
<%# app/views/registrations/new.html.erb %>
<div class="max-w-md mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-6">Sign Up</h1>

  <%= form_with model: @user, url: registrations_path, class: "space-y-6" do |form| %>
    <% if @user.errors.any? %>
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <h2 class="text-red-800 font-medium mb-2"><%= pluralize(@user.errors.count, "error") %> prevented signup:</h2>
        <ul class="list-disc list-inside text-red-700 text-sm">
          <% @user.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div>
      <%= form.label :name, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.text_field :name, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
    </div>

    <div>
      <%= form.label :email_address, "Email", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.email_field :email_address, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
    </div>

    <div>
      <%= form.label :password, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.password_field :password, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
    </div>

    <div>
      <%= form.label :password_confirmation, "Confirm Password", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.password_field :password_confirmation, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
    </div>

    <div>
      <%= form.label :default_hourly_rate, "Default Hourly Rate (optional)", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.number_field :default_hourly_rate, step: 0.01, min: 0, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>

    <div>
      <%= form.submit "Create Account", class: "w-full bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg cursor-pointer" %>
    </div>

    <p class="text-center text-gray-600">
      Already have an account?
      <%= link_to "Log in", new_session_path, class: "text-blue-600 hover:text-blue-800" %>
    </p>
  <% end %>
</div>
```

**Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/registrations_spec.rb`
Expected: All PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "Add user registration"
```

---

## Task 5: Style Login Page with Tailwind

**Files:**
- Modify: `app/views/sessions/new.html.erb`

**Step 1: Update login view**

```erb
<%# app/views/sessions/new.html.erb %>
<div class="max-w-md mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-6">Log In</h1>

  <%= form_with url: session_path, class: "space-y-6" do |form| %>
    <div>
      <%= form.label :email_address, "Email", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.email_field :email_address, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
    </div>

    <div>
      <%= form.label :password, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.password_field :password, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
    </div>

    <div>
      <%= form.submit "Log In", class: "w-full bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg cursor-pointer" %>
    </div>

    <p class="text-center text-gray-600">
      Don't have an account?
      <%= link_to "Sign up", new_registration_path, class: "text-blue-600 hover:text-blue-800" %>
    </p>
  <% end %>
</div>
```

**Step 2: Commit**

```bash
git add -A
git commit -m "Style login page with Tailwind"
```

---

## Task 6: Add Authentication to SalaryEntriesController

**Files:**
- Modify: `app/controllers/salary_entries_controller.rb`
- Modify: `spec/requests/salary_entries_spec.rb`

**Step 1: Update request specs to include authentication**

```ruby
# spec/requests/salary_entries_spec.rb
require 'rails_helper'

RSpec.describe "SalaryEntries", type: :request do
  let(:user) { create(:user) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /salary_entries" do
    it "returns success" do
      get salary_entries_path
      expect(response).to have_http_status(:success)
    end

    it "filters by year" do
      create(:salary_entry, user: user, month: 6, year: 2024, hours_worked: 100)
      create(:salary_entry, user: user, month: 1, year: 2025, hours_worked: 160)

      get salary_entries_path(year: 2025)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("January")
      expect(response.body).not_to include("June")
    end

    it "only shows current user entries" do
      other_user = create(:user)
      create(:salary_entry, user: other_user, month: 3, year: 2025)
      create(:salary_entry, user: user, month: 1, year: 2025)

      get salary_entries_path(year: 2025)

      expect(response.body).to include("January")
      expect(response.body).not_to include("March")
    end
  end

  describe "GET /salary_entries/:id" do
    it "returns success for own entry" do
      entry = create(:salary_entry, user: user)
      get salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end

    it "returns not found for other user entry" do
      other_user = create(:user)
      entry = create(:salary_entry, user: other_user)
      expect {
        get salary_entry_path(entry)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /salary_entries/new" do
    it "returns success" do
      get new_salary_entry_path
      expect(response).to have_http_status(:success)
    end

    it "pre-fills hourly rate from user default" do
      user.update!(default_hourly_rate: 75.0)
      get new_salary_entry_path
      expect(response.body).to include("75.0")
    end
  end

  describe "POST /salary_entries" do
    let(:valid_params) do
      { salary_entry: { month: 1, year: 2025, hours_worked: 160, hourly_rate: 50 } }
    end

    it "creates a new entry for current user" do
      expect {
        post salary_entries_path, params: valid_params
      }.to change(user.salary_entries, :count).by(1)
    end

    it "redirects to show page" do
      post salary_entries_path, params: valid_params
      expect(response).to redirect_to(salary_entry_path(SalaryEntry.last))
    end
  end

  describe "GET /salary_entries/:id/edit" do
    it "returns success for own entry" do
      entry = create(:salary_entry, user: user)
      get edit_salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /salary_entries/:id" do
    let(:entry) { create(:salary_entry, user: user, hours_worked: 160) }

    it "updates the entry" do
      patch salary_entry_path(entry), params: { salary_entry: { hours_worked: 180 } }
      expect(entry.reload.hours_worked).to eq(180)
    end

    it "redirects to show page" do
      patch salary_entry_path(entry), params: { salary_entry: { hours_worked: 180 } }
      expect(response).to redirect_to(salary_entry_path(entry))
    end
  end

  describe "DELETE /salary_entries/:id" do
    it "deletes the entry" do
      entry = create(:salary_entry, user: user)
      expect {
        delete salary_entry_path(entry)
      }.to change(SalaryEntry, :count).by(-1)
    end

    it "redirects to index" do
      entry = create(:salary_entry, user: user)
      delete salary_entry_path(entry)
      expect(response).to redirect_to(salary_entries_path)
    end
  end

  describe "GET /salary_entries/summary" do
    it "returns success" do
      get summary_salary_entries_path(year: 2025)
      expect(response).to have_http_status(:success)
    end
  end

  context "when not logged in" do
    before { delete session_path }

    it "redirects to login" do
      get salary_entries_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: FAIL - authentication not enforced

**Step 3: Update controller with authentication and scoping**

```ruby
# app/controllers/salary_entries_controller.rb
class SalaryEntriesController < ApplicationController
  before_action :set_salary_entry, only: [:show, :edit, :update, :destroy]

  def index
    @year = params[:year]&.to_i || Date.current.year
    @salary_entries = current_user.salary_entries.for_year(@year).ordered
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse
    @available_years = [@year] if @available_years.empty?
  end

  def show
  end

  def new
    @salary_entry = current_user.salary_entries.new(
      year: Date.current.year,
      month: Date.current.month,
      hourly_rate: current_user.default_hourly_rate
    )
  end

  def create
    @salary_entry = current_user.salary_entries.new(salary_entry_params)

    if @salary_entry.save
      redirect_to @salary_entry, notice: "Salary entry was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @salary_entry.update(salary_entry_params)
      redirect_to @salary_entry, notice: "Salary entry was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @salary_entry.destroy
    redirect_to salary_entries_path, notice: "Salary entry was successfully deleted."
  end

  def summary
    @year = params[:year]&.to_i || Date.current.year
    @summary = current_user.salary_entries.yearly_summary(@year)
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse
    @available_years = [@year] if @available_years.empty?
  end

  private

  def set_salary_entry
    @salary_entry = current_user.salary_entries.find(params[:id])
  end

  def salary_entry_params
    params.require(:salary_entry).permit(:month, :year, :hours_worked, :hourly_rate)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Add authentication to SalaryEntriesController"
```

---

## Task 7: Add Navigation Header

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Update layout with navigation header**

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <title>Salary Calculator</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="manifest" href="/manifest.json">
    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-gray-100 min-h-screen">
    <nav class="bg-white shadow">
      <div class="max-w-6xl mx-auto px-4 py-4">
        <div class="flex justify-between items-center">
          <%= link_to "Salary Calculator", root_path, class: "text-xl font-bold text-gray-900" %>

          <div class="flex items-center gap-4">
            <% if authenticated? %>
              <span class="text-gray-600"><%= Current.user.name %></span>
              <%= button_to "Log out", session_path, method: :delete,
                  class: "text-gray-600 hover:text-gray-800" %>
            <% else %>
              <%= link_to "Log in", new_session_path, class: "text-gray-600 hover:text-gray-800" %>
              <%= link_to "Sign up", new_registration_path,
                  class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg" %>
            <% end %>
          </div>
        </div>
      </div>
    </nav>

    <% if notice %>
      <div class="max-w-6xl mx-auto px-4 mt-4">
        <div class="bg-green-50 border border-green-200 text-green-800 rounded-lg p-4">
          <%= notice %>
        </div>
      </div>
    <% end %>

    <% if alert %>
      <div class="max-w-6xl mx-auto px-4 mt-4">
        <div class="bg-red-50 border border-red-200 text-red-800 rounded-lg p-4">
          <%= alert %>
        </div>
      </div>
    <% end %>

    <main class="py-8">
      <%= yield %>
    </main>
  </body>
</html>
```

**Step 2: Add authenticated? helper to ApplicationController**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication

  helper_method :authenticated?

  private

  def authenticated?
    Current.user.present?
  end
end
```

**Step 3: Commit**

```bash
git add -A
git commit -m "Add navigation header with auth links"
```

---

## Task 8: Final Verification

**Step 1: Run all specs**

Run: `bundle exec rspec`
Expected: All PASS

**Step 2: Start server and manual test**

Run: `bin/dev`

Manual verification checklist:
- [ ] Visit http://localhost:3000 (redirects to login)
- [ ] Click "Sign up" and create account
- [ ] Create a salary entry (hourly rate pre-filled if set)
- [ ] View entry details
- [ ] View yearly summary
- [ ] Log out
- [ ] Log in with different account
- [ ] Verify you can't see other user's entries

**Step 3: Final commit if any cleanup needed**

```bash
git status
# If clean, no commit needed
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Run Rails 8 authentication generator |
| 2 | Add custom User fields (name, default_hourly_rate) |
| 3 | Associate SalaryEntry with User |
| 4 | Create RegistrationsController |
| 5 | Style login page with Tailwind |
| 6 | Add authentication to SalaryEntriesController |
| 7 | Add navigation header |
| 8 | Final verification |

**Total: 8 tasks**
