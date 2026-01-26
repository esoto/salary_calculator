# Household/Shared View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> **IMPORTANT: Do NOT include Co-Authored-By or any Claude/AI references in commit messages**

**Goal:** Allow couples to see combined household finances while keeping individual dashboards.

**Architecture:** Create Household and HouseholdMembership models with join-by-code flow. Add household card to Settings page for create/join/leave. Create separate HouseholdController for combined dashboard view.

**Tech Stack:** Rails 8, RSpec, TailwindCSS, Chartkick

---

## Task 1: Create Household Model and Migration

**Files:**
- Create: `db/migrate/XXXXXX_create_households.rb`
- Create: `app/models/household.rb`
- Create: `spec/models/household_spec.rb`
- Create: `spec/factories/households.rb`

**Step 1: Write the failing tests**

Create `spec/models/household_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Household, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:invite_code) }

    it 'validates uniqueness of invite_code' do
      create(:household)
      should validate_uniqueness_of(:invite_code)
    end
  end

  describe 'associations' do
    it { should have_many(:household_memberships).dependent(:destroy) }
    it { should have_many(:members).through(:household_memberships).source(:user) }
  end

  describe 'invite_code generation' do
    it 'generates invite_code on create' do
      household = Household.create!(name: 'Test Family')
      expect(household.invite_code).to be_present
      expect(household.invite_code.length).to eq(6)
    end

    it 'generates uppercase alphanumeric code' do
      household = Household.create!(name: 'Test Family')
      expect(household.invite_code).to match(/\A[A-Z0-9]{6}\z/)
    end
  end

  describe '#regenerate_invite_code!' do
    it 'generates a new invite code' do
      household = create(:household)
      old_code = household.invite_code
      household.regenerate_invite_code!
      expect(household.invite_code).not_to eq(old_code)
    end
  end
end
```

**Step 2: Create factory**

Create `spec/factories/households.rb`:

```ruby
FactoryBot.define do
  factory :household do
    name { "Test Household" }
  end
end
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/household_spec.rb --format documentation`
Expected: FAIL - uninitialized constant Household

**Step 4: Create migration**

Run: `bin/rails generate migration CreateHouseholds name:string invite_code:string:index`

Edit the migration to add uniqueness constraint:

```ruby
class CreateHouseholds < ActiveRecord::Migration[8.0]
  def change
    create_table :households do |t|
      t.string :name, null: false
      t.string :invite_code, null: false

      t.timestamps
    end
    add_index :households, :invite_code, unique: true
  end
end
```

Run: `bin/rails db:migrate`

**Step 5: Implement the model**

Create `app/models/household.rb`:

```ruby
class Household < ApplicationRecord
  has_many :household_memberships, dependent: :destroy
  has_many :members, through: :household_memberships, source: :user

  validates :name, presence: true
  validates :invite_code, presence: true, uniqueness: true

  before_validation :generate_invite_code, on: :create

  def regenerate_invite_code!
    update!(invite_code: self.class.generate_unique_code)
  end

  private

  def generate_invite_code
    self.invite_code ||= self.class.generate_unique_code
  end

  def self.generate_unique_code
    loop do
      code = SecureRandom.alphanumeric(6).upcase
      break code unless exists?(invite_code: code)
    end
  end
end
```

**Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/household_spec.rb --format documentation`
Expected: All tests pass

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Household model with invite code generation"
```

---

## Task 2: Create HouseholdMembership Model and Migration

**Files:**
- Create: `db/migrate/XXXXXX_create_household_memberships.rb`
- Create: `app/models/household_membership.rb`
- Create: `spec/models/household_membership_spec.rb`
- Create: `spec/factories/household_memberships.rb`
- Modify: `app/models/user.rb`
- Modify: `spec/models/user_spec.rb`

**Step 1: Write the failing tests**

Create `spec/models/household_membership_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe HouseholdMembership, type: :model do
  describe 'associations' do
    it { should belong_to(:household) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { create(:household_membership) }

    it 'validates uniqueness of user_id' do
      should validate_uniqueness_of(:user_id).with_message('is already in a household')
    end
  end

  describe 'joined_at' do
    it 'sets joined_at on create' do
      membership = create(:household_membership)
      expect(membership.joined_at).to be_present
    end
  end
end
```

Add to `spec/models/user_spec.rb`:

```ruby
describe 'household association' do
  it { should have_one(:household_membership).dependent(:destroy) }
  it { should have_one(:household).through(:household_membership) }

  it 'returns nil when user has no household' do
    user = create(:user)
    expect(user.household).to be_nil
  end

  it 'returns household when user is a member' do
    user = create(:user)
    household = create(:household)
    create(:household_membership, user: user, household: household)
    expect(user.household).to eq(household)
  end
end
```

**Step 2: Create factory**

Create `spec/factories/household_memberships.rb`:

```ruby
FactoryBot.define do
  factory :household_membership do
    household
    user
  end
end
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/household_membership_spec.rb spec/models/user_spec.rb -e "household" --format documentation`
Expected: FAIL - uninitialized constant HouseholdMembership

**Step 4: Create migration**

Run: `bin/rails generate migration CreateHouseholdMemberships household:references user:references joined_at:datetime`

Edit the migration:

```ruby
class CreateHouseholdMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :household_memberships do |t|
      t.references :household, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :joined_at, null: false

      t.timestamps
    end
    add_index :household_memberships, :user_id, unique: true
  end
end
```

Run: `bin/rails db:migrate`

**Step 5: Implement the model**

Create `app/models/household_membership.rb`:

```ruby
class HouseholdMembership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  validates :user_id, uniqueness: { message: 'is already in a household' }

  before_create :set_joined_at

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
```

**Step 6: Update User model**

Add to `app/models/user.rb` after `has_many :salary_entries`:

```ruby
has_one :household_membership, dependent: :destroy
has_one :household, through: :household_membership
```

**Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/household_membership_spec.rb spec/models/user_spec.rb --format documentation`
Expected: All tests pass

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add HouseholdMembership model with user association"
```

---

## Task 3: Add Household Aggregation Methods

**Files:**
- Modify: `app/models/household.rb`
- Modify: `spec/models/household_spec.rb`

**Step 1: Write the failing tests**

Add to `spec/models/household_spec.rb`:

```ruby
describe '#combined_earnings_for_year' do
  let(:household) { create(:household) }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }

  before do
    create(:household_membership, household: household, user: user1)
    create(:household_membership, household: household, user: user2)
    create(:salary_entry, user: user1, year: 2026, month: 1, monthly_salary: 5000)
    create(:salary_entry, user: user1, year: 2026, month: 2, monthly_salary: 5000)
    create(:salary_entry, user: user2, year: 2026, month: 1, monthly_salary: 4000)
  end

  it 'sums earnings from all members for the year' do
    expect(household.combined_earnings_for_year(2026)).to eq(14000)
  end

  it 'returns 0 for year with no entries' do
    expect(household.combined_earnings_for_year(2025)).to eq(0)
  end
end

describe '#combined_savings_for_year' do
  let(:household) { create(:household) }
  let(:user1) { create(:user, aguinaldo_enabled: true, vacation_enabled: true, holiday_enabled: true) }
  let(:user2) { create(:user, aguinaldo_enabled: true, vacation_enabled: true, holiday_enabled: true) }

  before do
    create(:household_membership, household: household, user: user1)
    create(:household_membership, household: household, user: user2)
    create(:salary_entry, user: user1, year: 2026, month: 1, monthly_salary: 5000)
    create(:salary_entry, user: user2, year: 2026, month: 1, monthly_salary: 4000)
  end

  it 'sums savings from all members for the year' do
    total = household.combined_savings_for_year(2026)
    expect(total).to be > 0
  end
end

describe '#member_stats_for_year' do
  let(:household) { create(:household) }
  let(:user1) { create(:user, name: 'Alice') }
  let(:user2) { create(:user, name: 'Bob') }

  before do
    create(:household_membership, household: household, user: user1)
    create(:household_membership, household: household, user: user2)
    create(:salary_entry, user: user1, year: 2026, month: 1, monthly_salary: 5000)
    create(:salary_entry, user: user2, year: 2026, month: 1, monthly_salary: 4000)
  end

  it 'returns stats for each member' do
    stats = household.member_stats_for_year(2026)
    expect(stats.length).to eq(2)
    expect(stats.map { |s| s[:name] }).to contain_exactly('Alice', 'Bob')
  end

  it 'includes earnings and savings per member' do
    stats = household.member_stats_for_year(2026)
    alice_stats = stats.find { |s| s[:name] == 'Alice' }
    expect(alice_stats[:earnings]).to eq(5000)
    expect(alice_stats[:savings]).to be_present
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/household_spec.rb -e "combined" --format documentation`
Expected: FAIL - undefined method

**Step 3: Implement the methods**

Add to `app/models/household.rb`:

```ruby
def combined_earnings_for_year(year)
  SalaryEntry.where(user: members).for_year(year).sum(:monthly_salary)
end

def combined_savings_for_year(year)
  entries = SalaryEntry.where(user: members).for_year(year)
  entries.sum { |e| e.aguinaldo_savings + e.vacation_savings + e.holiday_savings }
end

def member_stats_for_year(year)
  members.map do |member|
    entries = member.salary_entries.for_year(year)
    earnings = entries.sum(:monthly_salary)
    savings = entries.sum { |e| e.aguinaldo_savings + e.vacation_savings + e.holiday_savings }
    {
      id: member.id,
      name: member.name,
      earnings: earnings,
      savings: savings
    }
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/household_spec.rb --format documentation`
Expected: All tests pass

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add household aggregation methods for combined stats"
```

---

## Task 4: Create HouseholdsController (Create/Join/Leave)

**Files:**
- Create: `app/controllers/households_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/requests/households_spec.rb`

**Step 1: Write the failing tests**

Create `spec/requests/households_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Households", type: :request do
  let(:user) { create(:user, password: 'password123') }

  before do
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe "POST /households" do
    it "creates a household and adds user as member" do
      expect {
        post households_path, params: { household: { name: 'Smith Family' } }
      }.to change(Household, :count).by(1)
        .and change(HouseholdMembership, :count).by(1)

      expect(response).to redirect_to(settings_path)
      expect(user.reload.household.name).to eq('Smith Family')
    end

    it "shows error if user already in household" do
      create(:household_membership, user: user)

      post households_path, params: { household: { name: 'New Family' } }

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to include('already')
    end
  end

  describe "POST /households/join" do
    let!(:household) { create(:household) }

    it "joins household with valid code" do
      expect {
        post join_households_path, params: { invite_code: household.invite_code }
      }.to change(HouseholdMembership, :count).by(1)

      expect(response).to redirect_to(settings_path)
      expect(user.reload.household).to eq(household)
    end

    it "shows error with invalid code" do
      post join_households_path, params: { invite_code: 'INVALID' }

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to include('Invalid')
    end

    it "shows error if already in household" do
      create(:household_membership, user: user)

      post join_households_path, params: { invite_code: household.invite_code }

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to include('already')
    end
  end

  describe "DELETE /households/:id/leave" do
    let!(:household) { create(:household) }
    let!(:membership) { create(:household_membership, user: user, household: household) }

    it "removes user from household" do
      expect {
        delete leave_household_path(household)
      }.to change(HouseholdMembership, :count).by(-1)

      expect(response).to redirect_to(settings_path)
      expect(user.reload.household).to be_nil
    end

    it "deletes household when last member leaves" do
      expect {
        delete leave_household_path(household)
      }.to change(Household, :count).by(-1)
    end

    it "keeps household when other members remain" do
      other_user = create(:user)
      create(:household_membership, user: other_user, household: household)

      expect {
        delete leave_household_path(household)
      }.not_to change(Household, :count)
    end
  end

  describe "POST /households/:id/regenerate_code" do
    let!(:household) { create(:household) }
    let!(:membership) { create(:household_membership, user: user, household: household) }

    it "generates new invite code" do
      old_code = household.invite_code

      post regenerate_code_household_path(household)

      expect(response).to redirect_to(settings_path)
      expect(household.reload.invite_code).not_to eq(old_code)
    end

    it "rejects non-members" do
      other_household = create(:household)

      post regenerate_code_household_path(other_household)

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to be_present
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/households_spec.rb --format documentation`
Expected: FAIL - routing errors

**Step 3: Add routes**

Modify `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  resource :session
  resource :settings, only: [ :show, :update ]
  resources :passwords, param: :token
  resources :registrations, only: [ :new, :create ]

  resources :households, only: [:create] do
    collection do
      post :join
    end
    member do
      delete :leave
      post :regenerate_code
    end
  end
  resource :household, only: [:show]

  get "dashboard", to: "dashboard#show"
  root "dashboard#show"

  resources :salary_entries do
    collection do
      get :summary
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

**Step 4: Implement the controller**

Create `app/controllers/households_controller.rb`:

```ruby
class HouseholdsController < ApplicationController
  before_action :require_no_household, only: [:create, :join]
  before_action :set_household, only: [:leave, :regenerate_code]
  before_action :require_membership, only: [:leave, :regenerate_code]

  def create
    @household = Household.new(household_params)

    if @household.save
      @household.household_memberships.create!(user: Current.user)
      redirect_to settings_path, notice: "Household created successfully."
    else
      redirect_to settings_path, alert: @household.errors.full_messages.join(", ")
    end
  end

  def join
    household = Household.find_by(invite_code: params[:invite_code]&.upcase)

    if household.nil?
      redirect_to settings_path, alert: "Invalid invite code."
    else
      household.household_memberships.create!(user: Current.user)
      redirect_to settings_path, notice: "You have joined #{household.name}."
    end
  end

  def leave
    @household.household_memberships.find_by(user: Current.user)&.destroy
    @household.destroy if @household.members.empty?
    redirect_to settings_path, notice: "You have left the household."
  end

  def regenerate_code
    @household.regenerate_invite_code!
    redirect_to settings_path, notice: "Invite code regenerated."
  end

  private

  def set_household
    @household = Household.find(params[:id])
  end

  def household_params
    params.require(:household).permit(:name)
  end

  def require_no_household
    if Current.user.household.present?
      redirect_to settings_path, alert: "You are already in a household."
    end
  end

  def require_membership
    unless Current.user.household == @household
      redirect_to settings_path, alert: "You are not a member of this household."
    end
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/households_spec.rb --format documentation`
Expected: All tests pass

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add HouseholdsController for create/join/leave/regenerate"
```

---

## Task 5: Add Household Card to Settings View

**Files:**
- Modify: `app/views/settings/show.html.erb`
- Modify: `app/controllers/settings_controller.rb`

**Step 1: Update Settings controller**

Add to `app/controllers/settings_controller.rb` in the `show` action (or create it if only `update` exists):

```ruby
def show
  @user = Current.user
  @household = Current.user.household
end
```

**Step 2: Add Household card to settings view**

Add after the Work Schedule card in `app/views/settings/show.html.erb`:

```erb
<!-- Household -->
<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-lg font-semibold text-gray-900 mb-4">Household</h2>

  <% if @household %>
    <div class="space-y-4">
      <div>
        <p class="text-sm text-gray-600">Household Name</p>
        <p class="font-medium text-gray-900"><%= @household.name %></p>
      </div>

      <div>
        <p class="text-sm text-gray-600">Members</p>
        <p class="font-medium text-gray-900">
          <%= @household.members.pluck(:name).join(", ") %>
        </p>
      </div>

      <div>
        <p class="text-sm text-gray-600 mb-1">Invite Code</p>
        <div class="flex items-center gap-2">
          <code class="bg-gray-100 px-3 py-1 rounded font-mono text-lg"><%= @household.invite_code %></code>
          <%= button_to "Regenerate", regenerate_code_household_path(@household),
              method: :post,
              class: "text-sm text-blue-600 hover:text-blue-800",
              data: { turbo_confirm: "Generate a new invite code? The old code will stop working." } %>
        </div>
      </div>

      <div class="pt-4 border-t border-gray-200">
        <%= button_to "Leave Household", leave_household_path(@household),
            method: :delete,
            class: "text-red-600 hover:text-red-800 text-sm",
            data: { turbo_confirm: "Are you sure? You will lose access to the combined household view." } %>
      </div>
    </div>
  <% else %>
    <p class="text-sm text-gray-600 mb-4">
      Create a household to share finances with your partner.
    </p>

    <div class="space-y-4">
      <!-- Create Household -->
      <%= form_with url: households_path, class: "space-y-3" do |f| %>
        <div>
          <%= f.label :name, "Household Name", class: "block text-sm font-medium text-gray-700 mb-1" %>
          <%= f.text_field :name, placeholder: "e.g., Smith Family",
              class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
        </div>
        <%= f.submit "Create Household",
            class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg cursor-pointer" %>
      <% end %>

      <div class="relative">
        <div class="absolute inset-0 flex items-center">
          <div class="w-full border-t border-gray-300"></div>
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="px-2 bg-white text-gray-500">or</span>
        </div>
      </div>

      <!-- Join Household -->
      <%= form_with url: join_households_path, class: "space-y-3" do |f| %>
        <div>
          <%= f.label :invite_code, "Join with Invite Code", class: "block text-sm font-medium text-gray-700 mb-1" %>
          <%= f.text_field :invite_code, placeholder: "ABC123", maxlength: 6,
              class: "w-full border border-gray-300 rounded-lg px-3 py-2 uppercase font-mono" %>
        </div>
        <%= f.submit "Join Household",
            class: "bg-gray-200 hover:bg-gray-300 text-gray-800 px-4 py-2 rounded-lg cursor-pointer" %>
      <% end %>
    </div>
  <% end %>
</div>
```

**Step 3: Run all tests**

Run: `bundle exec rspec --format progress`
Expected: All tests pass

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add household card to settings page"
```

---

## Task 6: Create Household Dashboard Controller and View

**Files:**
- Create: `app/controllers/household_controller.rb`
- Create: `app/views/household/show.html.erb`
- Create: `spec/requests/household_spec.rb`

**Step 1: Write the failing tests**

Create `spec/requests/household_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Household Dashboard", type: :request do
  let(:user) { create(:user, password: 'password123', name: 'Alice') }

  before do
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe "GET /household" do
    context "when user is not in a household" do
      it "redirects to dashboard with message" do
        get household_path

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("not a member")
      end
    end

    context "when user is in a household" do
      let(:household) { create(:household, name: 'Smith Family') }
      let(:partner) { create(:user, name: 'Bob') }

      before do
        create(:household_membership, user: user, household: household)
        create(:household_membership, user: partner, household: household)
        create(:salary_entry, user: user, year: 2026, month: 1, monthly_salary: 5000)
        create(:salary_entry, user: partner, year: 2026, month: 1, monthly_salary: 4000)
      end

      it "shows household dashboard" do
        get household_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Smith Family')
      end

      it "shows combined earnings" do
        get household_path

        expect(response.body).to include('9,000') # 5000 + 4000
      end

      it "shows member breakdown" do
        get household_path

        expect(response.body).to include('Alice')
        expect(response.body).to include('Bob')
      end

      it "supports year selection" do
        create(:salary_entry, user: user, year: 2025, month: 1, monthly_salary: 3000)

        get household_path(year: 2025)

        expect(response.body).to include('3,000')
      end
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/household_spec.rb --format documentation`
Expected: FAIL - controller not found

**Step 3: Implement the controller**

Create `app/controllers/household_controller.rb`:

```ruby
class HouseholdController < ApplicationController
  before_action :require_household_membership

  def show
    @household = Current.user.household

    # Available years from all members
    @available_years = SalaryEntry.where(user: @household.members)
                                  .distinct.pluck(:year).sort.reverse

    # Year selection
    selected_year = params[:year].to_i
    if (2020..2100).cover?(selected_year)
      @selected_year = selected_year
    else
      @selected_year = @available_years.first || Date.current.year
    end

    # Combined stats
    @combined_earnings = @household.combined_earnings_for_year(@selected_year)
    @combined_savings = @household.combined_savings_for_year(@selected_year)

    # Per-member breakdown
    @member_stats = @household.member_stats_for_year(@selected_year)

    # Chart data
    @savings_chart_data = prepare_household_chart_data(@selected_year)
  end

  private

  def require_household_membership
    unless Current.user.household.present?
      redirect_to dashboard_path, alert: "You are not a member of a household."
    end
  end

  def prepare_household_chart_data(year)
    @household.members.map do |member|
      entries_by_month = member.salary_entries.for_year(year).group_by(&:month)

      series_data = (1..12).map do |month|
        month_label = Date::MONTHNAMES[month][0..2]
        entry = entries_by_month[month]&.first
        value = entry ? (entry.aguinaldo_savings + entry.vacation_savings + entry.holiday_savings).to_f : 0
        [month_label, value]
      end

      { name: member.name, data: series_data }
    end
  end
end
```

**Step 4: Create the view**

Create `app/views/household/show.html.erb`:

```erb
<div class="max-w-6xl mx-auto px-4">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-gray-900"><%= @household.name %></h1>

    <%= form_with url: household_path, method: :get, class: "flex items-center gap-2" do %>
      <%= select_tag :year,
          options_for_select(@available_years.presence || [Date.current.year], @selected_year),
          class: "border border-gray-300 rounded-lg px-3 py-2",
          onchange: "this.form.submit()" %>
    <% end %>
  </div>

  <!-- Combined Stats -->
  <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
    <div class="bg-white rounded-lg shadow p-6">
      <p class="text-sm text-gray-600 mb-1">Combined Earnings</p>
      <p class="text-3xl font-bold text-gray-900"><%= number_to_currency(@combined_earnings) %></p>
      <p class="text-sm text-gray-500">YTD <%= @selected_year %></p>
    </div>

    <div class="bg-white rounded-lg shadow p-6">
      <p class="text-sm text-gray-600 mb-1">Combined Savings</p>
      <p class="text-3xl font-bold text-green-600"><%= number_to_currency(@combined_savings) %></p>
      <p class="text-sm text-gray-500">YTD <%= @selected_year %></p>
    </div>
  </div>

  <!-- Member Breakdown -->
  <div class="bg-white rounded-lg shadow p-6 mb-8">
    <h2 class="text-lg font-semibold text-gray-900 mb-4">By Member</h2>

    <div class="space-y-4">
      <% @member_stats.each do |member| %>
        <div class="flex justify-between items-center py-2 border-b border-gray-100 last:border-0">
          <span class="font-medium text-gray-900"><%= member[:name] %></span>
          <div class="text-right">
            <span class="text-gray-600"><%= number_to_currency(member[:earnings]) %> earnings</span>
            <span class="mx-2 text-gray-300">|</span>
            <span class="text-green-600"><%= number_to_currency(member[:savings]) %> savings</span>
          </div>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Combined Savings Chart -->
  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-4">Monthly Savings by Member</h2>
    <%= column_chart @savings_chart_data, stacked: true, library: { colors: ['#3b82f6', '#10b981', '#f59e0b', '#ef4444'] } %>
  </div>
</div>
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/household_spec.rb --format documentation`
Expected: All tests pass

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add household dashboard with combined stats and chart"
```

---

## Task 7: Add Household Link to Navigation

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Add conditional household link**

Modify the navigation in `app/views/layouts/application.html.erb`:

Replace the existing nav links section:

```erb
<div class="flex items-center gap-4">
  <% if authenticated? %>
    <%= link_to "Entries", salary_entries_path, class: "text-gray-600 hover:text-gray-800" %>
    <% if Current.user.household.present? %>
      <%= link_to "Household", household_path, class: "text-gray-600 hover:text-gray-800" %>
    <% end %>
    <%= link_to Current.user.name, settings_path, class: "text-gray-600 hover:text-gray-800" %>
    <%= button_to "Log out", session_path, method: :delete,
        class: "text-gray-600 hover:text-gray-800" %>
  <% else %>
    <%= link_to "Log in", new_session_path, class: "text-gray-600 hover:text-gray-800" %>
    <%= link_to "Sign up", new_registration_path,
        class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg" %>
  <% end %>
</div>
```

**Step 2: Run all tests**

Run: `bundle exec rspec --format progress`
Expected: All tests pass

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add conditional household link to navigation"
```

---

## Task 8: Run Linters and Full Test Suite

**Step 1: Run RuboCop**

Run: `bundle exec rubocop -a`
Fix any remaining offenses manually if needed.

**Step 2: Run full test suite**

Run: `bundle exec rspec --format progress`
Expected: All tests pass (should be ~220+ tests now)

**Step 3: Check coverage**

Run: `open coverage/index.html`
Verify coverage remains above 90%.

**Step 4: Commit any lint fixes**

```bash
git add -A
git commit -m "chore: lint fixes"
```

---

## Task 9: Create Pull Request

**Step 1: Push branch**

```bash
git push -u origin feature/household-shared-view
```

**Step 2: Create PR**

```bash
gh pr create --title "Add household shared view for couples" --body "$(cat <<'EOF'
## Summary
- Add Household model with invite code for joining
- Add HouseholdMembership to link users to households
- Add household management (create/join/leave) in Settings
- Add combined household dashboard at /household
- Show member breakdown and stacked savings chart

## Test plan
- [ ] Create a household from Settings
- [ ] Share invite code and join from another account
- [ ] View combined dashboard with both members' data
- [ ] Verify year selector works on household dashboard
- [ ] Leave household and verify cleanup
- [ ] Verify navigation shows/hides Household link correctly
EOF
)"
```

---

## Summary

| Task | Description | Tests Added |
|------|-------------|-------------|
| 1 | Household model | 5 |
| 2 | HouseholdMembership model | 5 |
| 3 | Household aggregation methods | 5 |
| 4 | HouseholdsController | 8 |
| 5 | Settings household card | 0 (UI) |
| 6 | Household dashboard | 5 |
| 7 | Navigation link | 0 (UI) |
| 8 | Linting | 0 |
| 9 | PR | 0 |

**Total new tests: ~28**
