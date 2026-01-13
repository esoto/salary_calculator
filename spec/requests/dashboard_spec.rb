# spec/requests/dashboard_spec.rb
require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, name: "Test User") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /dashboard" do
    it "returns success" do
      get dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "displays user name" do
      get dashboard_path
      expect(response.body).to include("Test User")
    end

    context 'when no year parameter provided' do
      it 'defaults to current year' do
        get dashboard_path
        expect(assigns(:selected_year)).to eq(Date.current.year)
      end

      it 'shows current year in header cards' do
        get dashboard_path
        expect(response.body).to include("YTD #{Date.current.year}")
      end
    end

    context 'when year parameter provided' do
      before do
        # Create entries for 2024
        create(:salary_entry, user: user, year: 2024, month: 1,
               hours_worked: 160, hourly_rate: 50)
        create(:salary_entry, user: user, year: 2024, month: 2,
               hours_worked: 160, hourly_rate: 50)

        # Create entries for 2025
        create(:salary_entry, user: user, year: 2025, month: 1,
               hours_worked: 160, hourly_rate: 60)
      end

      it 'filters data by selected year' do
        get dashboard_path(year: 2024)

        expect(assigns(:selected_year)).to eq(2024)
        expect(assigns(:months_logged)).to eq(2)
        expect(assigns(:total_earnings)).to eq(160 * 50 * 2) # 2024 entries only
      end

      it 'shows different data for different years' do
        get dashboard_path(year: 2025)

        expect(assigns(:selected_year)).to eq(2025)
        expect(assigns(:months_logged)).to eq(1)
        expect(assigns(:total_earnings)).to eq(160 * 60) # 2025 entry only
      end
    end

    context 'when invalid year parameter provided' do
      it 'defaults to current year for non-numeric year' do
        get dashboard_path(year: 'invalid')
        expect(assigns(:selected_year)).to eq(Date.current.year)
      end

      it 'defaults to current year for year below range' do
        get dashboard_path(year: 2019)
        expect(assigns(:selected_year)).to eq(Date.current.year)
      end

      it 'defaults to current year for year above range' do
        get dashboard_path(year: 2101)
        expect(assigns(:selected_year)).to eq(Date.current.year)
      end
    end

    describe 'available years' do
      it 'returns empty array when user has no entries' do
        get dashboard_path
        expect(assigns(:available_years)).to eq([])
      end

      it 'returns years with entries in descending order' do
        create(:salary_entry, user: user, year: 2023, month: 1)
        create(:salary_entry, user: user, year: 2025, month: 1)
        create(:salary_entry, user: user, year: 2024, month: 1)

        get dashboard_path
        expect(assigns(:available_years)).to eq([ 2025, 2024, 2023 ])
      end

      it 'does not include other users years' do
        other_user = create(:user)
        create(:salary_entry, user: user, year: 2024, month: 1)
        create(:salary_entry, user: other_user, year: 2023, month: 1)

        get dashboard_path
        expect(assigns(:available_years)).to eq([ 2024 ])
      end
    end
  end

  describe "GET / (root)" do
    it "shows dashboard" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
    end
  end

  context "when not logged in" do
    before { delete session_path }

    it "redirects to login" do
      get dashboard_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "with salary entries" do
    before do
      create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50)
      create(:salary_entry, user: user, month: 2, year: 2026, hours_worked: 140, hourly_rate: 50)
    end

    it "displays total earnings" do
      get dashboard_path
      expect(response.body).to include("15,000") # 160*50 + 140*50
    end

    it "displays months logged" do
      get dashboard_path
      expect(response.body).to include("2 of 12")
    end
  end

  context "data isolation" do
    it "does not show other user entries" do
      other_user = create(:user)
      create(:salary_entry, user: other_user, month: 1, year: 2026, hours_worked: 200, hourly_rate: 100)
      create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50)

      get dashboard_path
      expect(response.body).to include("8,000") # user's entry
      expect(response.body).not_to include("20,000") # other user's entry
    end
  end

  context "with time off taken" do
    before do
      create(:salary_entry, user: user, month: 1, year: 2026, hours_worked: 160, hourly_rate: 50,
             vacation_days_taken: 2, holiday_days_taken: 1)
    end

    it "displays available vacation days" do
      get dashboard_path
      # 1 month logged = 1.5 days earned, 2 taken = -0.5 available (or 0 if clamped)
      expect(response.body).to include("available")
    end

    it "displays days taken" do
      get dashboard_path
      expect(response.body).to include("taken")
    end
  end

  describe 'year selection integration' do
    before do
      # Create multi-year data
      create(:salary_entry, user: user, year: 2023, month: 1,
             hours_worked: 100, hourly_rate: 40)
      create(:salary_entry, user: user, year: 2024, month: 1,
             hours_worked: 150, hourly_rate: 50)
      create(:salary_entry, user: user, year: 2024, month: 2,
             hours_worked: 160, hourly_rate: 50)
      create(:salary_entry, user: user, year: 2025, month: 1,
             hours_worked: 170, hourly_rate: 60)
    end

    it 'displays correct data when switching years via parameter' do
      # View 2024 data
      get dashboard_path(year: 2024)
      expect(response).to have_http_status(:success)
      expect(assigns(:months_logged)).to eq(2)
      expect(assigns(:total_earnings)).to eq((150 * 50) + (160 * 50))

      # Switch to 2023 data
      get dashboard_path(year: 2023)
      expect(response).to have_http_status(:success)
      expect(assigns(:months_logged)).to eq(1)
      expect(assigns(:total_earnings)).to eq(100 * 40)

      # Switch to 2025 data
      get dashboard_path(year: 2025)
      expect(response).to have_http_status(:success)
      expect(assigns(:months_logged)).to eq(1)
      expect(assigns(:total_earnings)).to eq(170 * 60)
    end

    it 'includes year selector with all years in response' do
      get dashboard_path(year: 2024)

      expect(response.body).to include('Year:')
      expect(response.body).to include('value="2025"')
      expect(response.body).to include('value="2024"')
      expect(response.body).to include('value="2023"')
    end
  end

  describe 'savings chart data' do
    it 'prepares chart data with correct structure' do
      create(:salary_entry, user: user, year: 2025, month: 1,
             hours_worked: 160, hourly_rate: 50)

      get dashboard_path(year: 2025)

      expect(assigns(:savings_chart_data)).to be_a(Hash)
      expect(assigns(:savings_chart_data).keys).to match_array([ "Aguinaldo", "Vacation", "Holiday" ])
    end

    it 'includes all 12 months in chart data' do
      create(:salary_entry, user: user, year: 2025, month: 1)

      get dashboard_path(year: 2025)

      expect(assigns(:savings_chart_data)["Aguinaldo"].length).to eq(12)
      expect(assigns(:savings_chart_data)["Vacation"].length).to eq(12)
      expect(assigns(:savings_chart_data)["Holiday"].length).to eq(12)
    end

    it 'includes correct calculations for months with entries' do
      create(:salary_entry, user: user, year: 2025, month: 3,
             hours_worked: 160, hourly_rate: 60)

      get dashboard_path(year: 2025)

      march_aguinaldo = assigns(:savings_chart_data)["Aguinaldo"][2] # 0-indexed
      march_vacation = assigns(:savings_chart_data)["Vacation"][2]
      march_holiday = assigns(:savings_chart_data)["Holiday"][2]

      expect(march_aguinaldo[0]).to eq("Mar")
      expect(march_aguinaldo[1]).to eq(800.0) # (160 * 60) / 12
      expect(march_vacation[1]).to eq(720.0) # 12 * 60
      expect(march_holiday[1]).to be_within(0.01).of(400.0) # (10 * 8 / 12) * 60
    end

    it 'shows zero for months without entries' do
      create(:salary_entry, user: user, year: 2025, month: 6,
             hours_worked: 160, hourly_rate: 50)

      get dashboard_path(year: 2025)

      jan_aguinaldo = assigns(:savings_chart_data)["Aguinaldo"][0]
      expect(jan_aguinaldo[0]).to eq("Jan")
      expect(jan_aguinaldo[1]).to eq(0)
    end

    it 'respects selected year parameter' do
      create(:salary_entry, user: user, year: 2024, month: 1,
             hours_worked: 100, hourly_rate: 40)
      create(:salary_entry, user: user, year: 2025, month: 1,
             hours_worked: 160, hourly_rate: 50)

      get dashboard_path(year: 2024)

      jan_aguinaldo = assigns(:savings_chart_data)["Aguinaldo"][0]
      # Should use 2024 data: (100 * 40) / 12 = 333.33...
      expect(jan_aguinaldo[1]).to be_within(0.01).of(333.33)
    end
  end
end
