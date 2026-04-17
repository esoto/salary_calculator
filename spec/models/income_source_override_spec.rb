require "rails_helper"

RSpec.describe IncomeSourceOverride, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:income_source) }
  end

  describe "validations" do
    subject { build(:income_source_override) }

    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:year).is_greater_than_or_equal_to(2020).is_less_than_or_equal_to(2100).only_integer }
    it { is_expected.to validate_numericality_of(:month).is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12).only_integer }

    it "validates scope enum" do
      override = build(:income_source_override, scope: "bogus")
      expect(override).not_to be_valid
      expect(override.errors[:scope]).to be_present
    end

    it "rejects overrides on non-fixed income sources" do
      hourly_source = create(:income_source, income_type: "hourly", amount: nil)
      override = build(:income_source_override, income_source: hourly_source)
      expect(override).not_to be_valid
      expect(override.errors[:income_source].join).to match(/must be fixed/i)
    end

    it "enforces unique (source, year, month, scope) via DB index" do
      existing = create(:income_source_override)
      duplicate = build(:income_source_override,
                        income_source: existing.income_source,
                        year: existing.year, month: existing.month, scope: existing.scope)
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows both scopes to coexist for the same month" do
      existing = create(:income_source_override, scope: "single_month")
      other = build(:income_source_override,
                    income_source: existing.income_source,
                    year: existing.year, month: existing.month, scope: "from_this_month")
      expect(other).to be_valid
    end
  end

  describe "paper_trail" do
    it "tracks changes" do
      with_versioning do
        override = create(:income_source_override)
        expect(override.versions.count).to eq(1)
        override.update!(amount: 2000)
        expect(override.versions.count).to eq(2)
      end
    end
  end
end
