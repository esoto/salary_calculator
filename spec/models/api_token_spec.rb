require "rails_helper"

RSpec.describe ApiToken do
  let(:user) { create(:user) }

  describe "validations" do
    it "requires a name" do
      token = ApiToken.new(user: user, name: nil)
      expect(token).not_to be_valid
      expect(token.errors[:name]).to include("can't be blank")
    end
  end

  describe "token generation" do
    it "generates a plaintext token, digest, and hash on create" do
      token = ApiToken.create!(user: user, name: "test")
      expect(token.token).to be_present
      expect(token.token_digest).to be_present
      expect(token.token_hash).to eq(Digest::SHA256.hexdigest(token.token))
    end

    it "exposes the plaintext token only on the in-memory instance, not reloaded" do
      token = ApiToken.create!(user: user, name: "test")
      plaintext = token.token
      expect(plaintext).to be_present
      expect(ApiToken.find(token.id).token).to be_nil
    end
  end

  describe ".authenticate" do
    let!(:token_record) { ApiToken.create!(user: user, name: "test") }
    let(:plaintext) { token_record.token }

    it "returns the token when the plaintext matches" do
      expect(ApiToken.authenticate(plaintext)).to eq(token_record)
    end

    it "returns nil for an unknown token" do
      expect(ApiToken.authenticate("not-a-real-token")).to be_nil
    end

    it "returns nil when the token is inactive" do
      token_record.update!(active: false)
      expect(ApiToken.authenticate(plaintext)).to be_nil
    end

    it "returns nil when the token is expired" do
      token_record.update!(expires_at: 1.minute.ago)
      expect(ApiToken.authenticate(plaintext)).to be_nil
    end

    it "touches last_used_at on successful authentication" do
      freeze_time do
        expect { ApiToken.authenticate(plaintext) }
          .to change { token_record.reload.last_used_at }.from(nil).to(Time.current)
      end
    end

    it "returns nil for blank input" do
      expect(ApiToken.authenticate(nil)).to be_nil
      expect(ApiToken.authenticate("")).to be_nil
    end
  end

  describe "#expired?" do
    it "is false when expires_at is nil" do
      expect(ApiToken.new(expires_at: nil)).not_to be_expired
    end

    it "is true when expires_at is past" do
      expect(ApiToken.new(expires_at: 1.minute.ago)).to be_expired
    end
  end

  describe "scopes column" do
    it "defaults to empty string" do
      token = ApiToken.create!(user: user, name: "test")
      expect(token.scopes).to eq("")
    end

    it "stores space-separated scopes" do
      token = ApiToken.create!(user: user, name: "test", scopes: "budget:read")
      expect(token.scope_list).to contain_exactly("budget:read")
    end
  end

  describe "revocation with caching enabled" do
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original_cache
    end

    let!(:token_record) { ApiToken.create!(user: user, name: "test") }
    let(:plaintext) { token_record.token }

    it "stops authenticating immediately when deactivated, even within the cache window" do
      expect(ApiToken.authenticate(plaintext)).to eq(token_record)
      token_record.update!(active: false)
      expect(ApiToken.authenticate(plaintext)).to be_nil
    end

    it "stops authenticating immediately when expired, even within the cache window" do
      expect(ApiToken.authenticate(plaintext)).to eq(token_record)
      token_record.update!(expires_at: 1.second.ago)
      expect(ApiToken.authenticate(plaintext)).to be_nil
    end

    it "uses the cache to skip BCrypt on subsequent calls" do
      expect(ApiToken.authenticate(plaintext)).to eq(token_record)
      expect(BCrypt::Password).not_to receive(:new)
      expect(ApiToken.authenticate(plaintext)).to eq(token_record)
    end
  end

  describe "#inspect" do
    it "redacts the plaintext token" do
      token = ApiToken.create!(user: user, name: "test")
      expect(token.inspect).to include("[FILTERED]")
      expect(token.inspect).not_to include(token.token)
    end

    it "shows nil token on reloaded record" do
      token = ApiToken.create!(user: user, name: "test")
      reloaded = ApiToken.find(token.id)
      expect(reloaded.inspect).to include("token=nil")
    end
  end

  describe "#valid_token?" do
    it "is true for an active non-expired token" do
      token = ApiToken.create!(user: user, name: "test")
      expect(token).to be_valid_token
    end

    it "is false when inactive" do
      token = ApiToken.create!(user: user, name: "test")
      token.update!(active: false)
      expect(token).not_to be_valid_token
    end

    it "is false when expired" do
      token = ApiToken.create!(user: user, name: "test")
      token.update!(expires_at: 1.minute.ago)
      expect(token).not_to be_valid_token
    end
  end

  describe "#has_scope?" do
    it "returns true when the scope is present" do
      token = ApiToken.create!(user: user, name: "test", scopes: "budget:read admin:write")
      expect(token.has_scope?("budget:read")).to be true
    end

    it "returns false when the scope is absent" do
      token = ApiToken.create!(user: user, name: "test", scopes: "budget:read")
      expect(token.has_scope?("admin:write")).to be false
    end

    it "returns false when scopes is empty" do
      token = ApiToken.create!(user: user, name: "test", scopes: "")
      expect(token.has_scope?("budget:read")).to be false
    end
  end

  describe ".generate_secure_token" do
    it "returns a URL-safe base64 string" do
      expect(ApiToken.generate_secure_token).to match(/\A[A-Za-z0-9_\-]+\z/)
    end

    it "returns a different value each call" do
      expect(ApiToken.generate_secure_token).not_to eq(ApiToken.generate_secure_token)
    end
  end

  describe "expires_at_in_future validation" do
    it "rejects a new token with a past expires_at" do
      token = ApiToken.new(user: user, name: "test", expires_at: 1.minute.ago)
      expect(token).not_to be_valid
      expect(token.errors[:expires_at]).to include("must be in the future")
    end

    it "allows an existing token to be set to past expires_at (for revocation)" do
      token = ApiToken.create!(user: user, name: "test")
      expect { token.update!(expires_at: 1.minute.ago) }.not_to raise_error
    end
  end
end
