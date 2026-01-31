require 'rails_helper'

RSpec.describe IncomeSource, type: :model do
  describe "validations" do
    it { should belong_to(:user) }
    it { should belong_to(:linked_user).class_name("User").optional }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:currency) }
    it { should validate_presence_of(:income_type) }
    it { should validate_inclusion_of(:currency).in_array(%w[CRC USD]) }
    it { should validate_inclusion_of(:income_type).in_array(%w[hourly fixed]) }
  end

  describe "#amount_for_month" do
    let(:user) { create(:user) }

    context "with fixed income type" do
      let(:source) { create(:income_source, user: user, income_type: "fixed", amount: 5000, currency: "USD") }

      it "returns the fixed amount" do
        expect(source.amount_for_month(2026, 1)).to eq(5000)
      end
    end

    context "with hourly income type linked to user" do
      let(:linked_user) { create(:user) }
      let(:source) { create(:income_source, user: user, linked_user: linked_user, income_type: "hourly") }
      let!(:salary_entry) { create(:salary_entry, user: linked_user, year: 2026, month: 1, hours_worked: 160, hourly_rate: 50) }

      it "returns income from salary entry" do
        expect(source.amount_for_month(2026, 1)).to eq(8000)
      end

      it "returns 0 when no salary entry exists" do
        expect(source.amount_for_month(2026, 2)).to eq(0)
      end
    end
  end
end
