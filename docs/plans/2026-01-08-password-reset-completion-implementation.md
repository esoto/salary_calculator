# Password Reset Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> **IMPORTANT:** Do NOT include Claude references in commit messages. No "Generated with Claude Code", no "Co-Authored-By: Claude", etc.

**Goal:** Complete password reset via email feature by adding token generation, UI link, and comprehensive tests.

**Architecture:** Use Rails 8's `generates_token_for` for stateless, expiring tokens. Add "Forgot password?" link to login page. Write comprehensive test coverage for entire reset flow following TDD.

**Tech Stack:** Rails 8, RSpec, ActionMailer, `generates_token_for`

---

## Task 1: Add Token Generation to User Model

**Files:**
- Modify: `app/models/user.rb`
- Modify: `spec/models/user_spec.rb`

**Step 1: Write failing test for token generation**

Add to `spec/models/user_spec.rb` after existing validations:

```ruby
describe '#password_reset_token' do
  let(:user) { create(:user) }

  it 'generates a valid token' do
    token = user.password_reset_token
    expect(token).to be_present
    expect(token).to be_a(String)
  end

  it 'can find user by valid token' do
    token = user.password_reset_token
    found_user = User.find_by_password_reset_token!(token)
    expect(found_user).to eq(user)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/user_spec.rb -e "password_reset_token"`
Expected: FAIL - undefined method `password_reset_token`

**Step 3: Add generates_token_for to User model**

Add to `app/models/user.rb` after `has_secure_password`:

```ruby
has_secure_password
generates_token_for :password_reset, expires_in: 15.minutes
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/user_spec.rb -e "password_reset_token"`
Expected: 2 examples, 0 failures

**Step 5: Commit**

```bash
git add app/models/user.rb spec/models/user_spec.rb
git commit -m "Add password reset token generation to User model"
```

---

## Task 2: Test Token Expiration

**Files:**
- Modify: `spec/models/user_spec.rb`

**Step 1: Write failing test for token expiration**

Add to `spec/models/user_spec.rb` in the `#password_reset_token` describe block:

```ruby
it 'token expires after 15 minutes' do
  token = user.password_reset_token

  travel_to 16.minutes.from_now do
    expect {
      User.find_by_password_reset_token!(token)
    }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
  end
end
```

**Step 2: Run test to verify it passes**

Run: `bundle exec rspec spec/models/user_spec.rb -e "token expires"`
Expected: 1 example, 0 failures (should pass because generates_token_for already implements expiration)

**Step 3: Test token invalidation after password change**

Add to `spec/models/user_spec.rb` in the `#password_reset_token` describe block:

```ruby
it 'token is invalidated after password change' do
  token = user.password_reset_token

  user.update!(password: 'newpassword123', password_confirmation: 'newpassword123')

  expect {
    User.find_by_password_reset_token!(token)
  }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/models/user_spec.rb -e "token is invalidated"`
Expected: 1 example, 0 failures

**Step 5: Run all user model tests**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: All tests pass

**Step 6: Commit**

```bash
git add spec/models/user_spec.rb
git commit -m "Add tests for password reset token expiration and invalidation"
```

---

## Task 3: Add Forgot Password Link to Login Page

**Files:**
- Modify: `app/views/sessions/new.html.erb`

**Step 1: Add "Forgot password?" link**

In `app/views/sessions/new.html.erb`, update the password field div (around line 10-13):

```erb
<div>
  <%= form.label :password, class: "block text-sm font-medium text-gray-700 mb-1" %>
  <%= form.password_field :password, class: "w-full border border-gray-300 rounded-lg px-3 py-2", required: true %>
  <div class="text-right mt-1">
    <%= link_to "Forgot password?", new_password_path, class: "text-sm text-blue-600 hover:text-blue-800" %>
  </div>
</div>
```

**Step 2: Verify link is visible (manual check)**

Run: `bundle exec rails server`
Navigate to: `http://localhost:3000/session/new`
Expected: See "Forgot password?" link below password field

**Step 3: Commit**

```bash
git add app/views/sessions/new.html.erb
git commit -m "Add forgot password link to login page"
```

---

## Task 4: Write Request Specs for Password Reset Flow

**Files:**
- Create: `spec/requests/passwords_spec.rb`

**Step 1: Create spec file with basic structure**

Create `spec/requests/passwords_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  let(:user) { create(:user, email_address: 'user@example.com', password: 'password123', password_confirmation: 'password123') }

  describe "GET /passwords/new" do
    it "displays password reset request form" do
      get new_password_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Forgot your password?")
    end
  end
end
```

**Step 2: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/passwords_spec.rb`
Expected: 1 example, 0 failures

**Step 3: Add tests for POST /passwords**

Add to `spec/requests/passwords_spec.rb`:

```ruby
describe "POST /passwords" do
  before do
    ActionMailer::Base.deliveries.clear
  end

  context "with valid email" do
    it "sends password reset email" do
      post passwords_path, params: { email_address: user.email_address }

      expect(ActionMailer::Base.deliveries.count).to eq(1)
      email = ActionMailer::Base.deliveries.last
      expect(email.to).to eq([user.email_address])
      expect(email.subject).to eq("Reset your password")
    end

    it "redirects with success message" do
      post passwords_path, params: { email_address: user.email_address }

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("Password reset instructions sent")
    end
  end

  context "with invalid email" do
    it "does not send email" do
      post passwords_path, params: { email_address: 'nonexistent@example.com' }

      expect(ActionMailer::Base.deliveries.count).to eq(0)
    end

    it "still shows success message (security)" do
      post passwords_path, params: { email_address: 'nonexistent@example.com' }

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("Password reset instructions sent")
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/passwords_spec.rb -e "POST /passwords"`
Expected: 4 examples, 0 failures

**Step 5: Commit**

```bash
git add spec/requests/passwords_spec.rb
git commit -m "Add request specs for password reset request flow"
```

---

## Task 5: Write Request Specs for Token Validation

**Files:**
- Modify: `spec/requests/passwords_spec.rb`

**Step 1: Add tests for GET /passwords/:token/edit**

Add to `spec/requests/passwords_spec.rb`:

```ruby
describe "GET /passwords/:token/edit" do
  context "with valid token" do
    let(:token) { user.password_reset_token }

    it "displays password update form" do
      get edit_password_path(token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Update your password")
    end
  end

  context "with expired token" do
    let(:token) { user.password_reset_token }

    it "redirects with error message" do
      travel_to 16.minutes.from_now do
        get edit_password_path(token)

        expect(response).to redirect_to(new_password_path)
        follow_redirect!
        expect(response.body).to include("invalid or has expired")
      end
    end
  end

  context "with invalid token" do
    it "redirects with error message" do
      get edit_password_path('invalid-token')

      expect(response).to redirect_to(new_password_path)
      follow_redirect!
      expect(response.body).to include("invalid or has expired")
    end
  end
end
```

**Step 2: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/passwords_spec.rb -e "GET /passwords"`
Expected: 3 examples, 0 failures

**Step 3: Commit**

```bash
git add spec/requests/passwords_spec.rb
git commit -m "Add request specs for password reset token validation"
```

---

## Task 6: Write Request Specs for Password Update

**Files:**
- Modify: `spec/requests/passwords_spec.rb`

**Step 1: Add tests for PUT /passwords/:token**

Add to `spec/requests/passwords_spec.rb`:

```ruby
describe "PUT /passwords/:token" do
  let(:token) { user.password_reset_token }

  context "with matching passwords" do
    let(:new_password) { 'newpassword456' }

    it "updates the password" do
      put password_path(token), params: {
        password: new_password,
        password_confirmation: new_password
      }

      user.reload
      expect(user.authenticate(new_password)).to eq(user)
    end

    it "redirects to login with success message" do
      put password_path(token), params: {
        password: new_password,
        password_confirmation: new_password
      }

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("Password has been reset")
    end
  end

  context "with mismatched passwords" do
    it "does not update password" do
      original_digest = user.password_digest

      put password_path(token), params: {
        password: 'newpassword456',
        password_confirmation: 'different123'
      }

      user.reload
      expect(user.password_digest).to eq(original_digest)
    end

    it "redirects back with error" do
      put password_path(token), params: {
        password: 'newpassword456',
        password_confirmation: 'different123'
      }

      expect(response).to redirect_to(edit_password_path(token))
      follow_redirect!
      expect(response.body).to include("did not match")
    end
  end

  context "with used token" do
    it "cannot reuse token after password change" do
      # First use - should succeed
      put password_path(token), params: {
        password: 'newpassword456',
        password_confirmation: 'newpassword456'
      }

      # Try to use same token again - should fail
      get edit_password_path(token)
      expect(response).to redirect_to(new_password_path)
      follow_redirect!
      expect(response.body).to include("invalid or has expired")
    end
  end
end
```

**Step 2: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/passwords_spec.rb -e "PUT /passwords"`
Expected: 5 examples, 0 failures

**Step 3: Run all password request specs**

Run: `bundle exec rspec spec/requests/passwords_spec.rb`
Expected: 13 examples, 0 failures

**Step 4: Commit**

```bash
git add spec/requests/passwords_spec.rb
git commit -m "Add request specs for password update flow"
```

---

## Task 7: Write Mailer Specs

**Files:**
- Create: `spec/mailers/passwords_mailer_spec.rb`

**Step 1: Create mailer spec file**

Create `spec/mailers/passwords_mailer_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe PasswordsMailer, type: :mailer do
  describe '#reset' do
    let(:user) { create(:user, email_address: 'user@example.com') }
    let(:mail) { PasswordsMailer.reset(user) }

    it 'sends to correct email address' do
      expect(mail.to).to eq([user.email_address])
    end

    it 'has correct subject' do
      expect(mail.subject).to eq('Reset your password')
    end

    it 'includes reset link with token' do
      expect(mail.body.encoded).to include('password reset page')
      expect(mail.body.encoded).to include(edit_password_url(user.password_reset_token))
    end

    it 'mentions 15 minute expiration' do
      expect(mail.body.encoded).to include('15 minutes')
    end
  end
end
```

**Step 2: Run mailer specs**

Run: `bundle exec rspec spec/mailers/passwords_mailer_spec.rb`
Expected: 4 examples, 0 failures

**Step 3: Commit**

```bash
git add spec/mailers/passwords_mailer_spec.rb
git commit -m "Add mailer specs for password reset email"
```

---

## Task 8: Final Verification

**Files:**
- None (verification only)

**Step 1: Run all specs**

Run: `bundle exec rspec`
Expected: All tests pass (should be 81 + new tests = ~98 tests)

**Step 2: Manual testing checklist**

Run: `bundle exec rails server`

- [ ] Visit `/session/new` and see "Forgot password?" link
- [ ] Click link, redirects to `/passwords/new`
- [ ] Enter email, submit form
- [ ] Check terminal/logs for email delivery
- [ ] Copy reset URL from email/logs
- [ ] Visit reset URL in browser
- [ ] Enter new password (matching)
- [ ] Submit, redirected to login
- [ ] Log in with new password

**Step 3: Check for any uncommitted changes**

Run: `git status`
Expected: working tree clean

**Step 4: Review commit history**

Run: `git log --oneline -10`
Expected: See all 7 commits for this feature

---

## Summary

| Task | Description | Tests Added |
|------|-------------|-------------|
| 1 | Add token generation to User model | 2 model specs |
| 2 | Test token expiration and invalidation | 2 model specs |
| 3 | Add forgot password link to login page | 0 (visual check) |
| 4 | Request specs for password reset request | 5 request specs |
| 5 | Request specs for token validation | 3 request specs |
| 6 | Request specs for password update | 5 request specs |
| 7 | Mailer specs for reset email | 4 mailer specs |
| 8 | Final verification | Manual testing |

**Total: 7 implementation tasks, ~21 new tests**

**Estimated time:** 30-45 minutes following TDD
