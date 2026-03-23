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

    it "shows error with blank name" do
      expect {
        post households_path, params: { household: { name: '' } }
      }.not_to change(Household, :count)

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to include("Name can't be blank")
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

    it "ignores household ID param and uses current user's household" do
      other_household = create(:household)

      # Even though we pass other_household's ID, set_household should
      # scope to current_user.household, not Household.find(params[:id])
      delete leave_household_path(other_household)

      expect(response).to redirect_to(settings_path)
      # User should have left their own household, not the other one
      expect(user.reload.household).to be_nil
    end

    it "redirects when user has no household" do
      membership.destroy

      delete leave_household_path(household)

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to be_present
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

    it "ignores household ID param and regenerates own household code" do
      other_household = create(:household)
      old_code = household.invite_code

      post regenerate_code_household_path(other_household)

      expect(response).to redirect_to(settings_path)
      expect(household.reload.invite_code).not_to eq(old_code)
      expect(other_household.reload.invite_code).to eq(other_household.invite_code)
    end

    it "redirects when user has no household" do
      membership.destroy

      post regenerate_code_household_path(household)

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to be_present
    end
  end
end
