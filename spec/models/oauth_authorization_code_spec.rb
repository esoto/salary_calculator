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

    it "uses empty scopes when none provided" do
      result = OauthAuthorizationCode.issue(user: user, redirect_uri: "https://example.test/cb")
      expect(result.record.scopes).to eq("")
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
      barrier = Concurrent::CyclicBarrier.new(2)
      plaintext = issued.plaintext

      results = Array.new(2) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.wait
            OauthAuthorizationCode.consume(
              plaintext: plaintext,
              redirect_uri: "https://example.test/cb"
            )
          end
        end
      end.map(&:value)

      expect(results.compact.size).to eq(1)
      expect(results.count(nil)).to eq(1)
    end

    it "returns nil for an empty plaintext" do
      expect(
        OauthAuthorizationCode.consume(plaintext: "", redirect_uri: "https://example.test/cb")
      ).to be_nil
    end

    it "returns nil for a nil plaintext" do
      expect(
        OauthAuthorizationCode.consume(plaintext: nil, redirect_uri: "https://example.test/cb")
      ).to be_nil
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
