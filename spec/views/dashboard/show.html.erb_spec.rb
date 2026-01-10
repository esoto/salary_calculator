require 'rails_helper'

RSpec.describe 'dashboard/show.html.erb', type: :view do
  let(:user) { create(:user) }

  before do
    def view.current_user
      @current_user
    end
    view.instance_variable_set(:@current_user, user)

    assign(:months_logged, 2)
    assign(:total_earnings, 16000)
    assign(:net_pay, 14000)
    assign(:aguinaldo_savings, 1333)
    assign(:vacation_savings, 1200)
    assign(:vacation_spent, 0)
    assign(:vacation_balance, 1200)
    assign(:holiday_savings, 667)
    assign(:holiday_spent, 0)
    assign(:holiday_balance, 667)
    assign(:vacation_days_earned, 3.0)
    assign(:vacation_days_taken, 0)
    assign(:vacation_days_available, 3.0)
    assign(:holiday_days_earned, 1.67)
    assign(:holiday_days_taken, 0)
    assign(:holiday_days_available, 1.67)
    assign(:total_savings, 2000)
    assign(:recent_entries, [])
    assign(:selected_year, 2025)
    assign(:current_year, 2025)
  end

  context 'when user has no entries' do
    before do
      assign(:available_years, [])
    end

    it 'does not show year selector' do
      render
      expect(rendered).not_to match(/Year:/)
    end
  end

  context 'when user has entries' do
    before do
      assign(:available_years, [2025, 2024, 2023])
    end

    it 'shows year selector dropdown' do
      render
      expect(rendered).to match(/Year:/)
      expect(rendered).to include('select')
      expect(rendered).to include('name="year"')
    end

    it 'includes all available years in dropdown' do
      render
      expect(rendered).to include('value="2025"')
      expect(rendered).to include('value="2024"')
      expect(rendered).to include('value="2023"')
    end

    it 'marks selected year as selected' do
      render
      expect(rendered).to include('selected="selected"')
      expect(rendered).to include('value="2025"')
    end
  end
end
