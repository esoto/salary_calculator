# Salary Entry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a salary tracking system for contractors to record monthly hours/rates and calculate savings for aguinaldo, vacation, and holidays.

**Architecture:** Rails RESTful resource with a single `SalaryEntry` model. Calculations are instance methods (not stored). Constants for vacation/holiday days live in a concern for future extraction.

**Tech Stack:** Rails 8, RSpec, FactoryBot, Shoulda Matchers, Tailwind CSS v4

---

## Task 1: Create SalaryEntry Model with Migration

**Files:**
- Create: `app/models/salary_entry.rb`
- Create: `db/migrate/XXXXXX_create_salary_entries.rb`
- Create: `spec/models/salary_entry_spec.rb`
- Create: `spec/factories/salary_entries.rb`

**Step 1: Write the factory**

```ruby
# spec/factories/salary_entries.rb
FactoryBot.define do
  factory :salary_entry do
    month { 1 }
    year { 2025 }
    hours_worked { 160.0 }
    hourly_rate { 50.0 }
  end
end
```

**Step 2: Write the failing model validation tests**

```ruby
# spec/models/salary_entry_spec.rb
require 'rails_helper'

RSpec.describe SalaryEntry, type: :model do
  describe 'validations' do
    subject { build(:salary_entry) }

    it { should validate_presence_of(:month) }
    it { should validate_presence_of(:year) }
    it { should validate_presence_of(:hours_worked) }
    it { should validate_presence_of(:hourly_rate) }

    it { should validate_numericality_of(:month).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12) }
    it { should validate_numericality_of(:year).only_integer.is_greater_than_or_equal_to(2020).is_less_than_or_equal_to(2100) }
    it { should validate_numericality_of(:hours_worked).is_greater_than(0) }
    it { should validate_numericality_of(:hourly_rate).is_greater_than(0) }

    it { should validate_uniqueness_of(:month).scoped_to(:year) }
  end
end
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - model doesn't exist

**Step 4: Generate model and migration**

Run: `rails generate model SalaryEntry month:integer year:integer hours_worked:decimal hourly_rate:decimal`

**Step 5: Update migration with constraints**

```ruby
# db/migrate/XXXXXX_create_salary_entries.rb
class CreateSalaryEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :salary_entries do |t|
      t.integer :month, null: false
      t.integer :year, null: false
      t.decimal :hours_worked, precision: 10, scale: 2, null: false
      t.decimal :hourly_rate, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :salary_entries, [:month, :year], unique: true
  end
end
```

**Step 6: Run migration**

Run: `rails db:migrate`

**Step 7: Add validations to model**

```ruby
# app/models/salary_entry.rb
class SalaryEntry < ApplicationRecord
  validates :month, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :hours_worked, presence: true,
                           numericality: { greater_than: 0 }
  validates :hourly_rate, presence: true,
                          numericality: { greater_than: 0 }
  validates :month, uniqueness: { scope: :year }
end
```

**Step 8: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: All PASS

**Step 9: Commit**

```bash
git add -A
git commit -m "Add SalaryEntry model with validations"
```

---

## Task 2: Add Calculation Constants Concern

**Files:**
- Create: `app/models/concerns/salary_calculations.rb`
- Modify: `app/models/salary_entry.rb`
- Modify: `spec/models/salary_entry_spec.rb`

**Step 1: Write failing tests for calculation methods**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe 'calculations' do
  let(:entry) { build(:salary_entry, hours_worked: 160, hourly_rate: 50.0) }

  describe '#monthly_salary' do
    it 'calculates hours_worked * hourly_rate' do
      expect(entry.monthly_salary).to eq(8000.0)
    end
  end

  describe '#aguinaldo_savings' do
    it 'calculates monthly_salary / 12' do
      expect(entry.aguinaldo_savings).to be_within(0.01).of(666.67)
    end
  end

  describe '#vacation_savings' do
    it 'calculates 12 hours * hourly_rate (18 days * 8 hours / 12 months)' do
      expect(entry.vacation_savings).to eq(600.0)
    end
  end

  describe '#holiday_savings' do
    it 'calculates 6.67 hours * hourly_rate (10 days * 8 hours / 12 months)' do
      expect(entry.holiday_savings).to be_within(0.01).of(333.33)
    end
  end

  describe '#total_savings' do
    it 'sums all savings' do
      expected = entry.aguinaldo_savings + entry.vacation_savings + entry.holiday_savings
      expect(entry.total_savings).to be_within(0.01).of(expected)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - methods don't exist

**Step 3: Create the calculations concern**

```ruby
# app/models/concerns/salary_calculations.rb
module SalaryCalculations
  extend ActiveSupport::Concern

  VACATION_DAYS = 18
  HOLIDAYS = 10
  HOURS_PER_DAY = 8

  VACATION_HOURS_PER_MONTH = (VACATION_DAYS * HOURS_PER_DAY) / 12.0
  HOLIDAY_HOURS_PER_MONTH = (HOLIDAYS * HOURS_PER_DAY) / 12.0

  def monthly_salary
    hours_worked * hourly_rate
  end

  def aguinaldo_savings
    monthly_salary / 12.0
  end

  def vacation_savings
    VACATION_HOURS_PER_MONTH * hourly_rate
  end

  def holiday_savings
    HOLIDAY_HOURS_PER_MONTH * hourly_rate
  end

  def total_savings
    aguinaldo_savings + vacation_savings + holiday_savings
  end
end
```

**Step 4: Include concern in model**

```ruby
# app/models/salary_entry.rb
class SalaryEntry < ApplicationRecord
  include SalaryCalculations

  # ... validations remain unchanged
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: All PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "Add salary calculation methods"
```

---

## Task 3: Add Yearly Scopes and Summary

**Files:**
- Modify: `app/models/salary_entry.rb`
- Modify: `spec/models/salary_entry_spec.rb`

**Step 1: Write failing tests for yearly scope and summary**

Add to `spec/models/salary_entry_spec.rb`:

```ruby
describe 'scopes' do
  describe '.for_year' do
    let!(:entry_2024) { create(:salary_entry, month: 1, year: 2024) }
    let!(:entry_2025_jan) { create(:salary_entry, month: 1, year: 2025) }
    let!(:entry_2025_feb) { create(:salary_entry, month: 2, year: 2025) }

    it 'returns entries for the given year' do
      expect(SalaryEntry.for_year(2025)).to contain_exactly(entry_2025_jan, entry_2025_feb)
    end
  end
end

describe '.yearly_summary' do
  before do
    create(:salary_entry, month: 1, year: 2025, hours_worked: 160, hourly_rate: 50.0)
    create(:salary_entry, month: 2, year: 2025, hours_worked: 140, hourly_rate: 50.0)
  end

  it 'returns aggregated totals for the year' do
    summary = SalaryEntry.yearly_summary(2025)

    expect(summary[:total_earnings]).to eq(15000.0)
    expect(summary[:total_aguinaldo]).to be_within(0.01).of(1250.0)
    expect(summary[:total_vacation]).to eq(1200.0)
    expect(summary[:total_holidays]).to be_within(0.01).of(666.67)
    expect(summary[:total_savings]).to be_within(0.01).of(3116.67)
    expect(summary[:entries_count]).to eq(2)
  end

  it 'returns zeros for year with no entries' do
    summary = SalaryEntry.yearly_summary(2020)

    expect(summary[:total_earnings]).to eq(0)
    expect(summary[:entries_count]).to eq(0)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: FAIL - methods don't exist

**Step 3: Add scope and class method to model**

Add to `app/models/salary_entry.rb` after `include SalaryCalculations`:

```ruby
scope :for_year, ->(year) { where(year: year) }
scope :ordered, -> { order(:year, :month) }

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
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/salary_entry_spec.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Add yearly scope and summary method"
```

---

## Task 4: Create SalaryEntries Controller

**Files:**
- Create: `app/controllers/salary_entries_controller.rb`
- Create: `spec/requests/salary_entries_spec.rb`
- Modify: `config/routes.rb`

**Step 1: Write failing request specs for index**

```ruby
# spec/requests/salary_entries_spec.rb
require 'rails_helper'

RSpec.describe "SalaryEntries", type: :request do
  describe "GET /salary_entries" do
    it "returns success" do
      get salary_entries_path
      expect(response).to have_http_status(:success)
    end

    it "filters by year" do
      create(:salary_entry, month: 1, year: 2024)
      create(:salary_entry, month: 1, year: 2025)

      get salary_entries_path(year: 2025)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("2025")
      expect(response.body).not_to include("2024")
    end
  end

  describe "GET /salary_entries/:id" do
    it "returns success" do
      entry = create(:salary_entry)
      get salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /salary_entries/new" do
    it "returns success" do
      get new_salary_entry_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /salary_entries" do
    let(:valid_params) do
      { salary_entry: { month: 1, year: 2025, hours_worked: 160, hourly_rate: 50 } }
    end

    it "creates a new entry" do
      expect {
        post salary_entries_path, params: valid_params
      }.to change(SalaryEntry, :count).by(1)
    end

    it "redirects to show page" do
      post salary_entries_path, params: valid_params
      expect(response).to redirect_to(salary_entry_path(SalaryEntry.last))
    end
  end

  describe "GET /salary_entries/:id/edit" do
    it "returns success" do
      entry = create(:salary_entry)
      get edit_salary_entry_path(entry)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /salary_entries/:id" do
    let(:entry) { create(:salary_entry, hours_worked: 160) }

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
      entry = create(:salary_entry)
      expect {
        delete salary_entry_path(entry)
      }.to change(SalaryEntry, :count).by(-1)
    end

    it "redirects to index" do
      entry = create(:salary_entry)
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
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: FAIL - routes don't exist

**Step 3: Add routes**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :salary_entries do
    collection do
      get :summary
    end
  end

  root "salary_entries#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
```

**Step 4: Run tests to verify they still fail**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: FAIL - controller doesn't exist

**Step 5: Create controller**

```ruby
# app/controllers/salary_entries_controller.rb
class SalaryEntriesController < ApplicationController
  before_action :set_salary_entry, only: [:show, :edit, :update, :destroy]

  def index
    @year = params[:year]&.to_i || Date.current.year
    @salary_entries = SalaryEntry.for_year(@year).ordered
    @available_years = SalaryEntry.distinct.pluck(:year).sort.reverse
    @available_years = [@year] if @available_years.empty?
  end

  def show
  end

  def new
    @salary_entry = SalaryEntry.new(year: Date.current.year, month: Date.current.month)
  end

  def create
    @salary_entry = SalaryEntry.new(salary_entry_params)

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
    @summary = SalaryEntry.yearly_summary(@year)
    @available_years = SalaryEntry.distinct.pluck(:year).sort.reverse
    @available_years = [@year] if @available_years.empty?
  end

  private

  def set_salary_entry
    @salary_entry = SalaryEntry.find(params[:id])
  end

  def salary_entry_params
    params.require(:salary_entry).permit(:month, :year, :hours_worked, :hourly_rate)
  end
end
```

**Step 6: Run tests (will fail, need views)**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: FAIL - missing templates

**Step 7: Commit controller and routes**

```bash
git add -A
git commit -m "Add SalaryEntries controller and routes"
```

---

## Task 5: Create Views with Tailwind

**Files:**
- Create: `app/views/salary_entries/index.html.erb`
- Create: `app/views/salary_entries/show.html.erb`
- Create: `app/views/salary_entries/new.html.erb`
- Create: `app/views/salary_entries/edit.html.erb`
- Create: `app/views/salary_entries/_form.html.erb`
- Create: `app/views/salary_entries/summary.html.erb`
- Create: `app/helpers/salary_entries_helper.rb`

**Step 1: Create helper for month names**

```ruby
# app/helpers/salary_entries_helper.rb
module SalaryEntriesHelper
  def month_name(month)
    Date::MONTHNAMES[month]
  end

  def format_currency(amount)
    number_to_currency(amount, precision: 2)
  end

  def format_hours(hours)
    number_with_precision(hours, precision: 2)
  end
end
```

**Step 2: Create index view**

```erb
<%# app/views/salary_entries/index.html.erb %>
<div class="max-w-6xl mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold text-gray-900">Salary Entries</h1>
    <div class="flex gap-4">
      <%= link_to "View Summary", summary_salary_entries_path(year: @year),
          class: "bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg" %>
      <%= link_to "New Entry", new_salary_entry_path,
          class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg" %>
    </div>
  </div>

  <div class="mb-6">
    <%= form_tag salary_entries_path, method: :get, class: "flex items-center gap-4" do %>
      <label for="year" class="font-medium text-gray-700">Year:</label>
      <%= select_tag :year, options_for_select(@available_years, @year),
          class: "border border-gray-300 rounded-lg px-3 py-2",
          onchange: "this.form.submit()" %>
    <% end %>
  </div>

  <% if @salary_entries.any? %>
    <div class="overflow-x-auto bg-white rounded-lg shadow">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Month</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Hours</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Rate</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Salary</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Aguinaldo</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Vacation</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Holidays</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Total Savings</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <% @salary_entries.each do |entry| %>
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap">
                <%= link_to month_name(entry.month), entry, class: "text-blue-600 hover:text-blue-800" %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right"><%= format_hours(entry.hours_worked) %></td>
              <td class="px-6 py-4 whitespace-nowrap text-right"><%= format_currency(entry.hourly_rate) %></td>
              <td class="px-6 py-4 whitespace-nowrap text-right font-medium"><%= format_currency(entry.monthly_salary) %></td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-green-600"><%= format_currency(entry.aguinaldo_savings) %></td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-green-600"><%= format_currency(entry.vacation_savings) %></td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-green-600"><%= format_currency(entry.holiday_savings) %></td>
              <td class="px-6 py-4 whitespace-nowrap text-right font-bold text-green-700"><%= format_currency(entry.total_savings) %></td>
              <td class="px-6 py-4 whitespace-nowrap text-right">
                <%= link_to "Edit", edit_salary_entry_path(entry), class: "text-gray-600 hover:text-gray-800 mr-3" %>
                <%= link_to "Delete", entry, method: :delete, data: { turbo_method: :delete, turbo_confirm: "Are you sure?" },
                    class: "text-red-600 hover:text-red-800" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% else %>
    <div class="text-center py-12 bg-white rounded-lg shadow">
      <p class="text-gray-500 mb-4">No salary entries for <%= @year %>.</p>
      <%= link_to "Create your first entry", new_salary_entry_path, class: "text-blue-600 hover:text-blue-800" %>
    </div>
  <% end %>
</div>
```

**Step 3: Create show view**

```erb
<%# app/views/salary_entries/show.html.erb %>
<div class="max-w-2xl mx-auto px-4 py-8">
  <div class="mb-6">
    <%= link_to "← Back to entries", salary_entries_path(year: @salary_entry.year), class: "text-blue-600 hover:text-blue-800" %>
  </div>

  <div class="bg-white rounded-lg shadow p-6">
    <h1 class="text-3xl font-bold text-gray-900 mb-6">
      <%= month_name(@salary_entry.month) %> <%= @salary_entry.year %>
    </h1>

    <div class="grid grid-cols-2 gap-6 mb-8">
      <div>
        <p class="text-sm text-gray-500">Hours Worked</p>
        <p class="text-2xl font-semibold"><%= format_hours(@salary_entry.hours_worked) %></p>
      </div>
      <div>
        <p class="text-sm text-gray-500">Hourly Rate</p>
        <p class="text-2xl font-semibold"><%= format_currency(@salary_entry.hourly_rate) %></p>
      </div>
    </div>

    <div class="border-t pt-6 mb-8">
      <p class="text-sm text-gray-500 mb-2">Monthly Salary</p>
      <p class="text-4xl font-bold text-gray-900"><%= format_currency(@salary_entry.monthly_salary) %></p>
    </div>

    <div class="border-t pt-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Savings Breakdown</h2>
      <div class="space-y-4">
        <div class="flex justify-between">
          <span class="text-gray-600">Aguinaldo (13th month)</span>
          <span class="font-medium text-green-600"><%= format_currency(@salary_entry.aguinaldo_savings) %></span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-600">Vacation (18 days)</span>
          <span class="font-medium text-green-600"><%= format_currency(@salary_entry.vacation_savings) %></span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-600">Holidays (10 days)</span>
          <span class="font-medium text-green-600"><%= format_currency(@salary_entry.holiday_savings) %></span>
        </div>
        <div class="flex justify-between border-t pt-4">
          <span class="font-semibold text-gray-900">Total Savings</span>
          <span class="font-bold text-green-700 text-xl"><%= format_currency(@salary_entry.total_savings) %></span>
        </div>
      </div>
    </div>

    <div class="mt-8 flex gap-4">
      <%= link_to "Edit", edit_salary_entry_path(@salary_entry),
          class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg" %>
      <%= link_to "Delete", @salary_entry, method: :delete,
          data: { turbo_method: :delete, turbo_confirm: "Are you sure?" },
          class: "bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg" %>
    </div>
  </div>
</div>
```

**Step 4: Create form partial**

```erb
<%# app/views/salary_entries/_form.html.erb %>
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

  <div class="flex gap-4">
    <%= form.submit class: "bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg cursor-pointer" %>
    <%= link_to "Cancel", salary_entries_path, class: "bg-gray-200 hover:bg-gray-300 text-gray-800 px-6 py-2 rounded-lg" %>
  </div>
<% end %>
```

**Step 5: Create new view**

```erb
<%# app/views/salary_entries/new.html.erb %>
<div class="max-w-xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-6">New Salary Entry</h1>
  <%= render "form", salary_entry: @salary_entry %>
</div>
```

**Step 6: Create edit view**

```erb
<%# app/views/salary_entries/edit.html.erb %>
<div class="max-w-xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-6">Edit Salary Entry</h1>
  <%= render "form", salary_entry: @salary_entry %>
</div>
```

**Step 7: Create summary view**

```erb
<%# app/views/salary_entries/summary.html.erb %>
<div class="max-w-4xl mx-auto px-4 py-8">
  <div class="mb-6">
    <%= link_to "← Back to entries", salary_entries_path(year: @year), class: "text-blue-600 hover:text-blue-800" %>
  </div>

  <h1 class="text-3xl font-bold text-gray-900 mb-6">Yearly Summary</h1>

  <div class="mb-6">
    <%= form_tag summary_salary_entries_path, method: :get, class: "flex items-center gap-4" do %>
      <label for="year" class="font-medium text-gray-700">Year:</label>
      <%= select_tag :year, options_for_select(@available_years, @year),
          class: "border border-gray-300 rounded-lg px-3 py-2",
          onchange: "this.form.submit()" %>
    <% end %>
  </div>

  <div class="bg-white rounded-lg shadow p-6">
    <div class="grid grid-cols-2 gap-6 mb-8">
      <div class="bg-gray-50 rounded-lg p-4">
        <p class="text-sm text-gray-500">Entries Recorded</p>
        <p class="text-3xl font-bold text-gray-900"><%= @summary[:entries_count] %> / 12</p>
      </div>
      <div class="bg-blue-50 rounded-lg p-4">
        <p class="text-sm text-blue-600">Total Earnings</p>
        <p class="text-3xl font-bold text-blue-900"><%= format_currency(@summary[:total_earnings]) %></p>
      </div>
    </div>

    <h2 class="text-lg font-semibold text-gray-900 mb-4">Total Savings for <%= @year %></h2>

    <div class="space-y-4">
      <div class="flex justify-between items-center p-4 bg-green-50 rounded-lg">
        <span class="text-gray-700">Aguinaldo (13th month)</span>
        <span class="text-xl font-semibold text-green-700"><%= format_currency(@summary[:total_aguinaldo]) %></span>
      </div>
      <div class="flex justify-between items-center p-4 bg-green-50 rounded-lg">
        <span class="text-gray-700">Vacation (18 days)</span>
        <span class="text-xl font-semibold text-green-700"><%= format_currency(@summary[:total_vacation]) %></span>
      </div>
      <div class="flex justify-between items-center p-4 bg-green-50 rounded-lg">
        <span class="text-gray-700">Holidays (10 days)</span>
        <span class="text-xl font-semibold text-green-700"><%= format_currency(@summary[:total_holidays]) %></span>
      </div>
      <div class="flex justify-between items-center p-6 bg-green-100 rounded-lg border-2 border-green-200">
        <span class="text-lg font-semibold text-gray-900">Total Savings</span>
        <span class="text-3xl font-bold text-green-800"><%= format_currency(@summary[:total_savings]) %></span>
      </div>
    </div>
  </div>
</div>
```

**Step 8: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/salary_entries_spec.rb`
Expected: All PASS

**Step 9: Commit views**

```bash
git add -A
git commit -m "Add Tailwind-styled views for salary entries"
```

---

## Task 6: Final Verification

**Step 1: Run all specs**

Run: `bundle exec rspec`
Expected: All PASS

**Step 2: Start server and manual test**

Run: `bin/dev`

Manual verification checklist:
- [ ] Visit http://localhost:3000
- [ ] Create a new salary entry
- [ ] View the entry details
- [ ] Edit the entry
- [ ] View the summary page
- [ ] Delete an entry

**Step 3: Final commit if any cleanup needed**

```bash
git status
# If clean, no commit needed
```

---

## Summary

| Task | Description | Estimated Steps |
|------|-------------|-----------------|
| 1 | Model with validations | 9 steps |
| 2 | Calculation concern | 6 steps |
| 3 | Yearly scope/summary | 5 steps |
| 4 | Controller with specs | 7 steps |
| 5 | Tailwind views | 9 steps |
| 6 | Final verification | 3 steps |

**Total: 39 steps across 6 tasks**
