require "rails_helper"

RSpec.describe BudgetShare, type: :model do
  describe "associations" do
    it { should belong_to(:monthly_budget) }
  end

  describe "validations" do
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
      expect(share.display_name).to eq("Share link from #{share.created_at.to_date}")
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
