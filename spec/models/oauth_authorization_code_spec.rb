require "rails_helper"

RSpec.describe OauthAuthorizationCode do
  let(:user) { create(:user) }

  describe ".issue" do
    it "creates a code, returns both the record and plaintext" do
      result = OauthAuthorizationCode.issue(
        user: user,
        redirect_uri: "https://example.test/cb",
        scopes: "budget:read"
      )

      expect(result.record).to be_persisted
      expect(result.plaintext).to be_present
      expect(result.record.code_digest).to eq(Digest::SHA256.hexdigest(result.plaintext))
      expect(result.record.expires_at).to be_within(2.seconds).of(60.seconds.from_now)
    end
  end

  describe ".consume" do
    let!(:issued) do
      OauthAuthorizationCode.issue(
        user: user,
        redirect_uri: "https://example.test/cb",
        scopes: "budget:read"
      )
    end

    it "returns the record and marks it used when valid" do
      record = OauthAuthorizationCode.consume(
        plaintext: issued.plaintext,
        redirect_uri: "https://example.test/cb"
      )

      expect(record).to eq(issued.record)
      expect(record.reload.used_at).to be_present
    end

    it "returns nil when already used" do
      OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://example.test/cb")
      second = OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://example.test/cb")
      expect(second).to be_nil
    end

    it "rejects concurrent second redemption atomically" do
      results = 2.times.map do
        OauthAuthorizationCode.consume(
          plaintext: issued.plaintext,
          redirect_uri: "https://example.test/cb"
        )
      end
      expect(results.compact.size).to eq(1)
      expect(results.count(nil)).to eq(1)
    end

    it "returns nil when expired" do
      issued.record.update!(expires_at: 1.second.ago)
      expect(
        OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://example.test/cb")
      ).to be_nil
    end

    it "returns nil when redirect_uri does not match" do
      expect(
        OauthAuthorizationCode.consume(plaintext: issued.plaintext, redirect_uri: "https://other.test/cb")
      ).to be_nil
    end

    it "returns nil for unknown code" do
      expect(
        OauthAuthorizationCode.consume(plaintext: "not-real", redirect_uri: "https://example.test/cb")
      ).to be_nil
    end
  end
end
