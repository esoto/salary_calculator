# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetsHelper, type: :helper do
  describe '#category_display_name' do
    it 'returns display name for fixed category' do
      expect(helper.category_display_name('fixed')).to eq('Fixed Expenses')
    end

    it 'returns display name for guilt_free category' do
      expect(helper.category_display_name('guilt_free')).to eq('Guilt-Free')
    end

    it 'returns display name for savings category' do
      expect(helper.category_display_name('savings')).to eq('Savings')
    end

    it 'returns display name for investments category' do
      expect(helper.category_display_name('investments')).to eq('Investments')
    end

    it 'returns humanized name for unknown category' do
      expect(helper.category_display_name('other_category')).to eq('Other category')
    end
  end

  describe '#category_target_range' do
    it 'returns range for fixed category' do
      expect(helper.category_target_range('fixed')).to eq('50-60%')
    end

    it 'returns range for guilt_free category' do
      expect(helper.category_target_range('guilt_free')).to eq('20-35%')
    end

    it 'returns range for savings category' do
      expect(helper.category_target_range('savings')).to eq('5-10%')
    end

    it 'returns single value for investments category' do
      expect(helper.category_target_range('investments')).to eq('10%')
    end

    it 'returns nil for unknown category' do
      expect(helper.category_target_range('unknown')).to be_nil
    end
  end

  describe '#category_status_color' do
    it 'returns green for ok status' do
      expect(helper.category_status_color(:ok)).to eq('text-green-600')
    end

    it 'returns yellow for warning status' do
      expect(helper.category_status_color(:warning)).to eq('text-yellow-600')
    end

    it 'returns red for low status' do
      expect(helper.category_status_color(:low)).to eq('text-red-600')
    end

    it 'returns red for high status' do
      expect(helper.category_status_color(:high)).to eq('text-red-600')
    end

    it 'returns gray for unknown status' do
      expect(helper.category_status_color(:unknown)).to eq('text-gray-600')
    end
  end

  describe '#category_status_bg' do
    it 'returns green background for ok status' do
      expect(helper.category_status_bg(:ok)).to eq('bg-green-100')
    end

    it 'returns yellow background for warning status' do
      expect(helper.category_status_bg(:warning)).to eq('bg-yellow-100')
    end

    it 'returns red background for low status' do
      expect(helper.category_status_bg(:low)).to eq('bg-red-100')
    end

    it 'returns red background for high status' do
      expect(helper.category_status_bg(:high)).to eq('bg-red-100')
    end

    it 'returns gray background for unknown status' do
      expect(helper.category_status_bg(:unknown)).to eq('bg-gray-100')
    end
  end

  describe '#category_status_icon' do
    it 'returns checkmark for ok status' do
      expect(helper.category_status_icon(:ok)).to eq('✓')
    end

    it 'returns warning icon for warning status' do
      expect(helper.category_status_icon(:warning)).to eq('⚠')
    end

    it 'returns down arrow for low status' do
      expect(helper.category_status_icon(:low)).to eq('↓')
    end

    it 'returns up arrow for high status' do
      expect(helper.category_status_icon(:high)).to eq('↑')
    end

    it 'returns empty string for unknown status' do
      expect(helper.category_status_icon(:unknown)).to eq('')
    end
  end

  describe '#month_options_for_select' do
    it 'returns all 12 months with name and number' do
      options = helper.month_options_for_select
      expect(options.length).to eq(12)
      expect(options.first).to eq([ 'January', 1 ])
      expect(options.last).to eq([ 'December', 12 ])
    end

    it 'includes June as the 6th option' do
      options = helper.month_options_for_select
      expect(options[5]).to eq([ 'June', 6 ])
    end
  end

  describe '#year_options_for_select' do
    it 'returns years from 5 years ago to next year by default' do
      current_year = Date.current.year
      options = helper.year_options_for_select
      expect(options.first).to eq(current_year + 1)
      expect(options.last).to eq(current_year - 5)
      expect(options.length).to eq(7)
    end

    it 'accepts custom range parameter' do
      current_year = Date.current.year
      options = helper.year_options_for_select(range: 2)
      expect(options.first).to eq(current_year + 1)
      expect(options.last).to eq(current_year - 2)
      expect(options.length).to eq(4)
    end

    it 'returns years in descending order' do
      options = helper.year_options_for_select
      expect(options).to eq(options.sort.reverse)
    end
  end

  describe "#activity_description" do
    let(:user) { create(:user) }
    let(:budget) { create(:monthly_budget, user: user) }

    context "for budget changes" do
      it "describes budget creation" do
        version = budget.versions.find_by(event: "create")
        expect(helper.activity_description(version)).to eq("created this budget")
      end

      it "describes exchange rate changes" do
        budget.update!(exchange_rate: 510)
        version = budget.versions.last
        expect(helper.activity_description(version)).to include("changed exchange rate")
      end

      it "describes sharing changes" do
        budget.update!(shared_with_household: true)
        version = budget.versions.last
        expect(helper.activity_description(version)).to include("shared this budget")
      end
    end

    context "for budget item changes" do
      let(:item) { create(:budget_item, monthly_budget: budget, name: "Netflix", amount: 15) }

      it "describes item creation" do
        version = item.versions.find_by(event: "create")
        expect(helper.activity_description(version)).to include("added")
        expect(helper.activity_description(version)).to include("Netflix")
      end

      it "describes amount changes" do
        item.update!(amount: 20)
        version = item.versions.last
        expect(helper.activity_description(version)).to include("changed")
        expect(helper.activity_description(version)).to include("Netflix")
      end

      it "describes paid status changes" do
        item.update!(paid: true)
        version = item.versions.last
        expect(helper.activity_description(version)).to include("marked")
        expect(helper.activity_description(version)).to include("paid")
      end
    end
  end

  describe "#activity_actor_name" do
    let(:user) { create(:user, name: "Maria") }
    let(:current_user) { create(:user, name: "John") }
    let(:budget) { create(:monthly_budget, user: user) }

    it "returns 'You' for current user's changes" do
      PaperTrail.request.whodunnit = current_user.id
      budget.update!(exchange_rate: 510)
      version = budget.versions.last
      expect(helper.activity_actor_name(version, current_user)).to eq("You")
    end

    it "returns user name for other users' changes" do
      PaperTrail.request.whodunnit = user.id
      budget.update!(exchange_rate: 510)
      version = budget.versions.last
      expect(helper.activity_actor_name(version, current_user)).to eq("Maria")
    end

    it "returns 'Someone' for unknown users" do
      PaperTrail.request.whodunnit = nil
      budget.update!(exchange_rate: 510)
      version = budget.versions.last
      expect(helper.activity_actor_name(version, current_user)).to eq("Someone")
    end
  end

  describe "#activity_time_ago" do
    let(:budget) { create(:monthly_budget) }

    it "returns a time ago string" do
      version = budget.versions.last
      expect(helper.activity_time_ago(version)).to match(/ago$/)
    end
  end
end
