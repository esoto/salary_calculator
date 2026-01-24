# User Profile Editing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add profile editing (name, email, password change) to the existing Settings page.

**Architecture:** Extend existing Settings controller/view with profile fields. Add password change validation to User model with virtual `current_password` attribute.

**Tech Stack:** Rails 8, RSpec, TailwindCSS

---

## Task 1: Add Password Change Validation to User Model

**Files:**
- Modify: `app/models/user.rb`
- Test: `spec/models/user_spec.rb`

**Step 1: Write the failing tests**

```ruby
# In spec/models/user_spec.rb, add new describe block:

describe "password change validation" do
  let(:user) { create(:user, password: "oldpassword123") }

  context "when password is being changed" do
    it "is valid with correct current password" do
      user.current_password = "oldpassword123"
      user.password = "newpassword123"
      user.password_confirmation = "newpassword123"
      expect(user).to be_valid
    end

    it "is invalid without current password" do
      user.password = "newpassword123"
      user.password_confirmation = "newpassword123"
      expect(user).not_to be_valid
      expect(user.errors[:current_password]).to include("can't be blank")
    end

    it "is invalid with incorrect current password" do
      user.current_password = "wrongpassword"
      user.password = "newpassword123"
      user.password_confirmation = "newpassword123"
      expect(user).not_to be_valid
      expect(user.errors[:current_password]).to include("is incorrect")
    end

    it "is invalid when password confirmation doesn't match" do
      user.current_password = "oldpassword123"
      user.password = "newpassword123"
      user.password_confirmation = "differentpassword"
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  context "when password is not being changed" do
    it "skips password validation when password fields are blank" do
      user.name = "New Name"
      expect(user).to be_valid
    end

    it "allows updating other fields without current password" do
      user.email_address = "newemail@example.com"
      expect(user).to be_valid
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/user_spec.rb -e "password change validation" --format documentation`
Expected: FAIL - `current_password` method not found

**Step 3: Implement the validation**

Add to `app/models/user.rb`:

```ruby
attr_accessor :current_password

validate :current_password_correct, if: :password_change_requested?

private

def password_change_requested?
  password.present?
end

def current_password_correct
  return if current_password.present? && authenticate(current_password)
  errors.add(:current_password, "is incorrect")
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/user_spec.rb -e "password change validation" --format documentation`
Expected: PASS (6 examples, 0 failures)

**Step 5: Commit**

```bash
git add app/models/user.rb spec/models/user_spec.rb
git commit -m "feat: add password change validation to User model"
```

---

## Task 2: Update Settings Controller to Permit Profile Params

**Files:**
- Modify: `app/controllers/settings_controller.rb`
- Test: `spec/requests/settings_spec.rb`

**Step 1: Write the failing tests**

```ruby
# In spec/requests/settings_spec.rb, add new describe blocks:

describe "profile updates" do
  describe "PATCH /settings - name update" do
    it "updates the user name" do
      patch settings_path, params: { user: { name: "New Name" } }
      expect(response).to redirect_to(settings_path)
      expect(user.reload.name).to eq("New Name")
    end
  end

  describe "PATCH /settings - email update" do
    it "updates the user email" do
      patch settings_path, params: { user: { email_address: "newemail@example.com" } }
      expect(response).to redirect_to(settings_path)
      expect(user.reload.email_address).to eq("newemail@example.com")
    end

    it "shows error for duplicate email" do
      create(:user, email_address: "taken@example.com")
      patch settings_path, params: { user: { email_address: "taken@example.com" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /settings - password change" do
    it "changes password with correct current password" do
      patch settings_path, params: {
        user: {
          current_password: "password123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        }
      }
      expect(response).to redirect_to(settings_path)
      expect(user.reload.authenticate("newpassword456")).to be_truthy
    end

    it "shows error for incorrect current password" do
      patch settings_path, params: {
        user: {
          current_password: "wrongpassword",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows error for mismatched confirmation" do
      patch settings_path, params: {
        user: {
          current_password: "password123",
          password: "newpassword456",
          password_confirmation: "differentpassword"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/settings_spec.rb -e "profile updates" --format documentation`
Expected: FAIL - params not permitted

**Step 3: Update controller params**

Modify `app/controllers/settings_controller.rb`:

```ruby
def settings_params
  params.require(:user).permit(
    :name,
    :email_address,
    :current_password,
    :password,
    :password_confirmation,
    :vacation_days_per_year,
    :holiday_days_per_year,
    :hours_per_day,
    :aguinaldo_enabled,
    :vacation_enabled,
    :holiday_enabled
  )
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/settings_spec.rb -e "profile updates" --format documentation`
Expected: PASS (6 examples, 0 failures)

**Step 5: Commit**

```bash
git add app/controllers/settings_controller.rb spec/requests/settings_spec.rb
git commit -m "feat: permit profile params in settings controller"
```

---

## Task 3: Add Profile Card to Settings View

**Files:**
- Modify: `app/views/settings/show.html.erb`

**Step 1: Review current view structure**

Read the existing view to understand the layout and styling patterns.

**Step 2: Add Profile card at the top**

Insert before the "Savings Preferences" card:

```erb
<!-- Profile -->
<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-lg font-semibold text-gray-900 mb-4">Profile</h2>

  <div class="space-y-4">
    <!-- Name -->
    <div>
      <%= form.label :name, class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.text_field :name, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>

    <!-- Email -->
    <div>
      <%= form.label :email_address, "Email", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.email_field :email_address, class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
    </div>

    <!-- Change Password -->
    <div class="border-t border-gray-200 pt-4 mt-4">
      <p class="text-sm font-medium text-gray-700 mb-1">Change Password</p>
      <p class="text-xs text-gray-500 mb-3">Leave blank to keep current password</p>

      <div class="space-y-3">
        <div>
          <%= form.label :current_password, class: "block text-sm text-gray-600 mb-1" %>
          <%= form.password_field :current_password, autocomplete: "current-password",
              class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
        </div>

        <div>
          <%= form.label :password, "New password", class: "block text-sm text-gray-600 mb-1" %>
          <%= form.password_field :password, autocomplete: "new-password",
              class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
        </div>

        <div>
          <%= form.label :password_confirmation, "Confirm new password", class: "block text-sm text-gray-600 mb-1" %>
          <%= form.password_field :password_confirmation, autocomplete: "new-password",
              class: "w-full border border-gray-300 rounded-lg px-3 py-2" %>
        </div>
      </div>
    </div>
  </div>
</div>
```

**Step 3: Run all tests to verify no regressions**

Run: `bundle exec rspec --format progress`
Expected: All tests pass

**Step 4: Commit**

```bash
git add app/views/settings/show.html.erb
git commit -m "feat: add profile card to settings view"
```

---

## Task 4: Run Linters and Full Test Suite

**Step 1: Run RuboCop**

Run: `bundle exec rubocop -a`
Expected: No offenses (or fix any that appear)

**Step 2: Run full test suite**

Run: `bundle exec rspec --format progress`
Expected: All tests pass (should be ~196+ tests)

**Step 3: Manual smoke test (optional)**

Start server and verify:
- Settings page shows Profile card at top
- Can update name
- Can update email
- Can change password with correct current password
- Errors shown for wrong current password

**Step 4: Final commit if any lint fixes**

```bash
git add -A
git commit -m "chore: lint fixes" # only if needed
```

---

## Task 5: Create Pull Request

**Step 1: Push branch**

```bash
git push -u origin feature/user-profile-editing
```

**Step 2: Create PR**

```bash
gh pr create --title "Add user profile editing to settings page" --body "$(cat <<'EOF'
## Summary
- Add profile editing section to Settings page
- Users can update name and email
- Users can change password (requires current password)

## Test plan
- [ ] Verify name can be updated
- [ ] Verify email can be updated
- [ ] Verify password change works with correct current password
- [ ] Verify error shown for incorrect current password
- [ ] Verify error shown for mismatched confirmation
- [ ] Verify existing settings functionality still works
EOF
)"
```
