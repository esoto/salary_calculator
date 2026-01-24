# Vacation Over-Limit Warning Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add soft validation warning when users take more vacation days than earned, requiring acknowledgment to proceed.

**Architecture:** Add `vacation_balance_for_year` method to User model for calculating YTD balance. Add custom validation to SalaryEntry that checks balance and requires acknowledgment via virtual attribute. Update form to show warning banner with checkbox when over limit.

**Tech Stack:** Ruby on Rails 8, RSpec, Tailwind CSS

**Implementation Notes:**
- Do NOT include Co-Authored-By or any Claude references in commit messages

---

### Task 1: Add vacation_balance_for_year method to User model

**Files:**
- Modify: `app/models/user.rb`
- Test: `spec/models/user_spec.rb`

**Step 1: Write the failing tests**

Add to `spec/models/user_spec.rb`:

```ruby
describe "#vacation_balance_for_year" do
  let(:user) { create(:user, vacation_days_per_year: 12) } # 1 day earned per month

  context "with no entries" do
    it "returns zero balance" do
      balance = user.vacation_balance_for_year(2025)
      expect(balance[:earned]).to eq(0)
      expect(balance[:taken]).to eq(0)
      expect(balance[:balance]).to eq(0)
    end
  end

  context "with entries and no vacation taken" do
    before do
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
      create(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 0)
    end

    it "calculates days earned based on entry count" do
      balance = user.vacation_balance_for_year(2025)
      expect(balance[:earned]).to eq(2.0) # 2 months * 1 day/month
      expect(balance[:taken]).to eq(0)
      expect(balance[:balance]).to eq(2.0)
    end
  end

  context "with vacation days taken" do
    before do
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5)
      create(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 1)
    end

    it "calculates correct balance" do
      balance = user.vacation_balance_for_year(2025)
      expect(balance[:earned]).to eq(2.0)
      expect(balance[:taken]).to eq(1.5)
      expect(balance[:balance]).to eq(0.5)
    end
  end

  context "with exclude_entry for new record" do
    before do
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
    end

    it "includes new entry in calculation" do
      new_entry = user.salary_entries.build(year: 2025, month: 2, vacation_days_taken: 1.5)
      balance = user.vacation_balance_for_year(2025, exclude_entry: new_entry)
      expect(balance[:earned]).to eq(2.0) # existing + new entry
      expect(balance[:taken]).to eq(1.5)  # new entry's days
      expect(balance[:balance]).to eq(0.5)
    end
  end

  context "with exclude_entry for persisted record" do
    let!(:entry) { create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 1) }

    it "excludes persisted value and includes new value" do
      entry.vacation_days_taken = 2.0 # changing from 1 to 2
      balance = user.vacation_balance_for_year(2025, exclude_entry: entry)
      expect(balance[:earned]).to eq(1.0)
      expect(balance[:taken]).to eq(2.0) # new value, not old
      expect(balance[:balance]).to eq(-1.0)
    end
  end

  context "with entries from different years" do
    before do
      create(:salary_entry, user: user, year: 2024, month: 12, vacation_days_taken: 5)
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 1)
    end

    it "only considers entries from specified year" do
      balance = user.vacation_balance_for_year(2025)
      expect(balance[:earned]).to eq(1.0)
      expect(balance[:taken]).to eq(1.0)
      expect(balance[:balance]).to eq(0.0)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/user_spec.rb -e "vacation_balance_for_year"`
Expected: FAIL with "undefined method `vacation_balance_for_year'"

**Step 3: Implement vacation_balance_for_year method**

Add to `app/models/user.rb` after the validations:

```ruby
def vacation_balance_for_year(year, exclude_entry: nil)
  entries = salary_entries.for_year(year)
  entries = entries.where.not(id: exclude_entry.id) if exclude_entry&.persisted?

  entries_count = entries.count
  entries_count += 1 if exclude_entry.present? && (exclude_entry.new_record? || exclude_entry.persisted?)

  days_earned = entries_count * (vacation_days_per_year / 12.0)
  days_taken = entries.sum(:vacation_days_taken)
  days_taken += exclude_entry.vacation_days_taken.to_f if exclude_entry.present?

  { earned: days_earned, taken: days_taken, balance: days_earned - days_taken }
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/user_spec.rb -e "vacation_balance_for_year"`
Expected: All tests PASS

**Step 5: Run full test suite**

Run: `bundle exec rspec`
Expected: All 161+ tests PASS

**Step 6: Commit**

```bash
git add app/models/user.rb spec/models/user_spec.rb
git commit -m "feat(user): add vacation_balance_for_year method"
```

---

### Task 2: Add vacation over-limit validation to SalaryEntry

**Files:**
- Modify: `app/models/salary_entry.rb`
- Test: `spec/models/salary_entry_spec.rb`

**Step 1: Write the failing tests**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe "vacation over-limit validation" do
  let(:user) { create(:user, vacation_days_per_year: 12, vacation_enabled: true) }

  context "when within limit" do
    it "is valid" do
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
      entry = build(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 1)
      expect(entry).to be_valid
    end
  end

  context "when over limit and not acknowledged" do
    it "is invalid" do
      entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 5)
      expect(entry).not_to be_valid
      expect(entry.errors[:base]).to include("You're taking more vacation days than earned. Please acknowledge this to continue.")
    end
  end

  context "when over limit and acknowledged" do
    it "is valid" do
      entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 5)
      entry.vacation_over_limit_acknowledged = "1"
      expect(entry).to be_valid
    end
  end

  context "when vacation is disabled" do
    let(:user) { create(:user, vacation_enabled: false) }

    it "skips validation" do
      entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 100)
      expect(entry).to be_valid
    end
  end

  context "when vacation_days_taken is zero" do
    it "skips validation" do
      entry = build(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0)
      expect(entry).to be_valid
    end
  end

  context "when editing existing entry" do
    let!(:entry) { create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5) }

    it "correctly calculates balance excluding old value" do
      entry.vacation_days_taken = 1.0 # still within limit (1 day earned)
      expect(entry).to be_valid
    end

    it "requires acknowledgment when new value exceeds limit" do
      entry.vacation_days_taken = 5.0 # over limit
      expect(entry).not_to be_valid
      entry.vacation_over_limit_acknowledged = "1"
      expect(entry).to be_valid
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb -e "vacation over-limit"`
Expected: FAIL with "undefined method `vacation_over_limit_acknowledged='"

**Step 3: Implement validation**

Add to `app/models/salary_entry.rb` after the existing validations:

```ruby
attr_accessor :vacation_over_limit_acknowledged

validate :vacation_within_limit_or_acknowledged

private

def vacation_within_limit_or_acknowledged
  return unless user&.vacation_enabled
  return if vacation_days_taken.to_f <= 0

  balance = user.vacation_balance_for_year(year, exclude_entry: self)
  return if balance[:balance] >= 0
  return if vacation_over_limit_acknowledged.present?

  errors.add(:base, "You're taking more vacation days than earned. Please acknowledge this to continue.")
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb -e "vacation over-limit"`
Expected: All tests PASS

**Step 5: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/models/salary_entry.rb spec/models/salary_entry_spec.rb
git commit -m "feat(salary_entry): add vacation over-limit validation with acknowledgment"
```

---

### Task 3: Update controller to handle over-limit state

**Files:**
- Modify: `app/controllers/salary_entries_controller.rb`
- Test: `spec/requests/salary_entries_spec.rb`

**Step 1: Write the failing tests**

Add to `spec/requests/salary_entries_spec.rb` (or create if needed):

```ruby
describe "vacation over-limit handling" do
  let(:user) { create(:user, vacation_days_per_year: 12, vacation_enabled: true) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /salary_entries/new" do
    it "calculates over_vacation_limit for new entry" do
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 1)
      get new_salary_entry_path, params: { year: 2025, month: 2 }
      expect(response).to be_successful
    end
  end

  describe "POST /salary_entries" do
    context "when over limit without acknowledgment" do
      it "re-renders form with warning" do
        post salary_entries_path, params: {
          salary_entry: {
            year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
            vacation_days_taken: 5
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when over limit with acknowledgment" do
      it "creates entry successfully" do
        post salary_entries_path, params: {
          salary_entry: {
            year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
            vacation_days_taken: 5, vacation_over_limit_acknowledged: "1"
          }
        }
        expect(response).to redirect_to(SalaryEntry.last)
      end
    end
  end
end
```

**Step 2: Run tests to verify current state**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb -e "vacation over-limit"`
Expected: May pass or fail depending on setup

**Step 3: Update controller**

Modify `app/controllers/salary_entries_controller.rb`:

Update `salary_entry_params` to permit the new attribute:

```ruby
def salary_entry_params
  params.require(:salary_entry).permit(:month, :year, :hours_worked, :hourly_rate,
                                        :vacation_days_taken, :holiday_days_taken,
                                        :vacation_over_limit_acknowledged)
end
```

Add helper methods and before_action:

```ruby
before_action :set_salary_entry, only: [ :show, :edit, :update, :destroy ]
before_action :calculate_vacation_limit_status, only: [ :new, :create, :edit, :update ]

# ... existing actions ...

private

def calculate_vacation_limit_status
  return unless current_user.vacation_enabled

  entry = @salary_entry || current_user.salary_entries.new(salary_entry_params_for_calculation)
  balance = current_user.vacation_balance_for_year(entry.year || Date.current.year, exclude_entry: entry)

  @over_vacation_limit = balance[:balance] < 0
  @vacation_over_by = balance[:balance].abs if @over_vacation_limit
  @vacation_balance = balance
end

def salary_entry_params_for_calculation
  return {} unless params[:salary_entry].present?
  params.require(:salary_entry).permit(:year, :vacation_days_taken)
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb -e "vacation over-limit"`
Expected: All tests PASS

**Step 5: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/controllers/salary_entries_controller.rb spec/requests/salary_entries_spec.rb
git commit -m "feat(controller): add vacation over-limit calculation and permit acknowledgment"
```

---

### Task 4: Add warning banner to salary entry form

**Files:**
- Modify: `app/views/salary_entries/_form.html.erb`
- Test: `spec/views/salary_entries/_form.html.erb_spec.rb`

**Step 1: Write the failing tests**

Create or update `spec/views/salary_entries/_form.html.erb_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "salary_entries/_form", type: :view do
  let(:user) { create(:user, vacation_enabled: true) }
  let(:salary_entry) { user.salary_entries.build(year: 2025, month: 1) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:salary_entry, salary_entry)
  end

  context "when not over vacation limit" do
    before do
      assign(:over_vacation_limit, false)
    end

    it "does not show warning banner" do
      render partial: "salary_entries/form", locals: { salary_entry: salary_entry }
      expect(rendered).not_to have_css(".bg-amber-50")
      expect(rendered).not_to have_content("Vacation days warning")
    end
  end

  context "when over vacation limit" do
    before do
      assign(:over_vacation_limit, true)
      assign(:vacation_over_by, 2.5)
    end

    it "shows warning banner with correct message" do
      render partial: "salary_entries/form", locals: { salary_entry: salary_entry }
      expect(rendered).to have_css(".bg-amber-50")
      expect(rendered).to have_content("Vacation days warning")
      expect(rendered).to have_content("2.5 more days than earned")
    end

    it "shows acknowledgment checkbox" do
      render partial: "salary_entries/form", locals: { salary_entry: salary_entry }
      expect(rendered).to have_field("salary_entry_vacation_over_limit_acknowledged")
      expect(rendered).to have_content("I understand this affects my savings")
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/views/salary_entries/_form.html.erb_spec.rb`
Expected: FAIL - warning banner not found

**Step 3: Update form view**

Modify `app/views/salary_entries/_form.html.erb` - add the warning banner before the submit button section:

```erb
<%= form_with model: salary_entry, class: "space-y-6" do |form| %>
  <% if salary_entry.errors.any? %>
    <div class="bg-red-50 border border-red-200 rounded-lg p-4">
      <h2 class="text-red-800 font-medium mb-2"><%= pluralize(salary_entry.errors.count, "error") %> prevented saving:</h2>
      <ul class="list-disc list-inside text-red-700 text-sm">
        <% salary_entry.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="grid grid-cols-2 gap-6">
    <div>
      <%= form.label :month, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.select :month, (1..12).map { |m| [Date::MONTHNAMES[m], m] },
          {}, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>

    <div>
      <%= form.label :year, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.number_field :year, min: 2020, max: 2100,
          class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>
  </div>

  <div class="grid grid-cols-2 gap-6">
    <div>
      <%= form.label :hours_worked, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.number_field :hours_worked, step: 0.01, min: 0,
          class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>

    <div>
      <%= form.label :hourly_rate, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.number_field :hourly_rate, step: 0.01, min: 0,
          class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>
  </div>

  <div class="grid grid-cols-2 gap-4">
    <% if current_user.vacation_enabled %>
      <div>
        <%= form.label :vacation_days_taken, "Vacation days taken", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= form.number_field :vacation_days_taken, step: 0.5, min: 0,
            class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
      </div>
    <% end %>
    <% if current_user.holiday_enabled %>
      <div>
        <%= form.label :holiday_days_taken, "Holiday days taken", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= form.number_field :holiday_days_taken, step: 0.5, min: 0,
            class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
      </div>
    <% end %>
  </div>

  <% if @over_vacation_limit %>
    <div class="bg-amber-50 border border-amber-200 rounded-lg p-4">
      <p class="text-amber-800 font-medium">Vacation days warning</p>
      <p class="text-amber-700 text-sm mt-1">
        You're taking <%= number_with_precision(@vacation_over_by, precision: 1, strip_insignificant_zeros: true) %>
        more days than earned. This means you'll need to use money from holiday
        and/or aguinaldo savings, affecting future finances.
      </p>
      <label class="flex items-center mt-3">
        <%= form.check_box :vacation_over_limit_acknowledged,
            class: "h-4 w-4 text-amber-600 rounded border-gray-300",
            checked: salary_entry.vacation_over_limit_acknowledged.present? %>
        <span class="ml-2 text-sm text-amber-800">I understand this affects my savings</span>
      </label>
    </div>
  <% end %>

  <div class="flex gap-4">
    <%= form.submit class: "bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg cursor-pointer" %>
    <%= link_to "Cancel", salary_entries_path, class: "bg-gray-200 hover:bg-gray-300 text-gray-800 px-6 py-2 rounded-lg" %>
  </div>
<% end %>
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/views/salary_entries/_form.html.erb_spec.rb`
Expected: All tests PASS

**Step 5: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/views/salary_entries/_form.html.erb spec/views/salary_entries/_form.html.erb_spec.rb
git commit -m "feat(view): add vacation over-limit warning banner with acknowledgment checkbox"
```

---

### Task 5: Fix controller calculation timing issue

**Files:**
- Modify: `app/controllers/salary_entries_controller.rb`

**Step 1: Review and fix the calculation timing**

The `calculate_vacation_limit_status` needs to work correctly for:
- `new` action: Calculate for a new unsaved entry
- `create` action: Calculate after failed validation (entry has params)
- `edit` action: Calculate for existing entry
- `update` action: Calculate after failed validation (entry has new params)

Update the controller to handle all cases:

```ruby
class SalaryEntriesController < ApplicationController
  before_action :set_salary_entry, only: [ :show, :edit, :update, :destroy ]

  def index
    @year = params[:year]&.to_i || Date.current.year
    @salary_entries = current_user.salary_entries.for_year(@year).ordered
    @available_years = current_user.salary_entries.distinct.pluck(:year).sort.reverse
    @available_years = [ @year ] if @available_years.empty?
  end

  def show
  end

  def new
    @salary_entry = current_user.salary_entries.new(
      year: Date.current.year,
      month: Date.current.month,
      hourly_rate: current_user.default_hourly_rate
    )
    calculate_vacation_limit_status
  end

  def create
    @salary_entry = current_user.salary_entries.new(salary_entry_params)
    calculate_vacation_limit_status

    if @salary_entry.save
      redirect_to @salary_entry, notice: "Salary entry was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    calculate_vacation_limit_status
  end

  def update
    @salary_entry.assign_attributes(salary_entry_params)
    calculate_vacation_limit_status

    if @salary_entry.save
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
    @available_years = [ @year ] if @available_years.empty?
  end

  private

  def set_salary_entry
    @salary_entry = current_user.salary_entries.find(params[:id])
  end

  def salary_entry_params
    params.require(:salary_entry).permit(:month, :year, :hours_worked, :hourly_rate,
                                          :vacation_days_taken, :holiday_days_taken,
                                          :vacation_over_limit_acknowledged)
  end

  def calculate_vacation_limit_status
    return unless current_user.vacation_enabled
    return unless @salary_entry.present?

    year = @salary_entry.year || Date.current.year
    balance = current_user.vacation_balance_for_year(year, exclude_entry: @salary_entry)

    @over_vacation_limit = balance[:balance] < 0
    @vacation_over_by = balance[:balance].abs if @over_vacation_limit
    @vacation_balance = balance
  end
end
```

**Step 2: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add app/controllers/salary_entries_controller.rb
git commit -m "fix(controller): improve vacation limit calculation timing for all actions"
```

---

### Task 6: Add integration test for full flow

**Files:**
- Create: `spec/requests/vacation_over_limit_spec.rb`

**Step 1: Write integration tests**

Create `spec/requests/vacation_over_limit_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Vacation Over-Limit Flow", type: :request do
  let(:user) { create(:user, vacation_days_per_year: 12, vacation_enabled: true) }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "creating entry within limit" do
    it "saves without warning" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 0.5
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
      expect(SalaryEntry.count).to eq(1)
    end
  end

  describe "creating entry over limit" do
    it "rejects without acknowledgment" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 5
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Vacation days warning")
      expect(response.body).to include("4.0 more days than earned")
      expect(SalaryEntry.count).to eq(0)
    end

    it "saves with acknowledgment" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 5,
          vacation_over_limit_acknowledged: "1"
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
      expect(SalaryEntry.count).to eq(1)
      expect(SalaryEntry.last.vacation_days_taken).to eq(5)
    end
  end

  describe "editing entry to go over limit" do
    let!(:entry) { create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5) }

    it "rejects increased days without acknowledgment" do
      patch salary_entry_path(entry), params: {
        salary_entry: { vacation_days_taken: 5 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Vacation days warning")
    end

    it "saves increased days with acknowledgment" do
      patch salary_entry_path(entry), params: {
        salary_entry: {
          vacation_days_taken: 5,
          vacation_over_limit_acknowledged: "1"
        }
      }

      expect(response).to redirect_to(entry)
      entry.reload
      expect(entry.vacation_days_taken).to eq(5)
    end
  end

  describe "YTD balance across multiple entries" do
    before do
      create(:salary_entry, user: user, year: 2025, month: 1, vacation_days_taken: 0.5)
      create(:salary_entry, user: user, year: 2025, month: 2, vacation_days_taken: 1.0)
      # 2 entries = 2 days earned, 1.5 taken, 0.5 remaining
    end

    it "considers previous entries when calculating limit" do
      # 3rd entry would earn 1 more day (total 3 earned)
      # Taking 2 days would mean 3.5 total taken, only 3 earned = 0.5 over
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 3, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 2
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Vacation days warning")
    end

    it "allows entry when YTD remains within limit" do
      # Taking 0.5 days = 2 total taken, 3 earned = within limit
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 3, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 0.5
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
    end
  end

  describe "when vacation is disabled" do
    let(:user) { create(:user, vacation_enabled: false) }

    it "allows any amount without warning" do
      post salary_entries_path, params: {
        salary_entry: {
          year: 2025, month: 1, hours_worked: 160, hourly_rate: 50,
          vacation_days_taken: 100
        }
      }

      expect(response).to redirect_to(SalaryEntry.last)
    end
  end
end
```

**Step 2: Run integration tests**

Run: `bundle exec rspec spec/requests/vacation_over_limit_spec.rb`
Expected: All tests PASS

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add spec/requests/vacation_over_limit_spec.rb
git commit -m "test: add integration tests for vacation over-limit flow"
```

---

### Task 7: Run linters and final verification

**Step 1: Run RuboCop**

Run: `bundle exec rubocop -a`
Expected: No offenses (or auto-corrected)

**Step 2: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS (should be ~175+ tests now)

**Step 3: Fix any issues**

If any lint or test issues, fix them.

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "style: fix rubocop offenses" # if needed
```

---

### Task 8: Create Pull Request

**Step 1: Push branch**

```bash
git push -u origin feature/vacation-over-limit-warning
```

**Step 2: Create PR**

```bash
gh pr create --title "feat: vacation over-limit warning with acknowledgment" --body "$(cat <<'EOF'
## Summary
- Adds soft validation when users take more vacation days than earned
- Shows amber warning banner explaining financial impact
- Requires checkbox acknowledgment to proceed
- Calculates YTD balance considering all entries for the year

## Test plan
- [ ] Create entry within vacation limit - saves without warning
- [ ] Create entry over limit without checkbox - shows warning, rejects save
- [ ] Create entry over limit with checkbox checked - saves successfully
- [ ] Edit entry to exceed limit - shows warning appropriately
- [ ] Multiple entries in year - YTD balance is calculated correctly
- [ ] Vacation disabled - no validation or warning shown

Closes: Vacation over-limit validation feature
EOF
)"
```

**Step 3: Report PR URL**

Report the PR URL to the user.
