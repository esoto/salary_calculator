# Pending Features

This document tracks features that have been identified but not yet implemented.

**Last Updated:** 2026-02-03

---

## Dashboard Enhancements

### Charts/Graphs for Trends
**Priority:** Low
**Complexity:** High

**Description:** Add visualizations to show earnings, savings, and time off trends over time.

**Requirements:**
- Line chart for monthly earnings over time
- Stacked bar chart for savings breakdown
- Time off usage visualization
- Year-over-year comparison charts
- Choose charting library (e.g., Chart.js, Recharts)

**Impact:** Improved data insights and user engagement

---

## Salary Entry Enhancements

### Multiple Entries Per Month
**Priority:** Low
**Complexity:** High

**Description:** Support tracking multiple salary entries within the same month for different clients or projects.

**Requirements:**
- Remove unique index on (user_id, year, month)
- Add optional client/project name field
- Update dashboard aggregations to sum multiple entries per month
- Update UI to show multiple entries clearly
- Handle time off tracking across multiple entries

**Impact:** Support freelancers with multiple clients

---

## Time Off Enhancements

### Carry Over Unused Days to Next Year
**Priority:** Medium
**Complexity:** Medium

**Description:** Roll over unused vacation and holiday days from one year to the next.

**Requirements:**
- Add carryover_vacation_days and carryover_holiday_days to users table
- Manual or automatic carryover at year-end
- Display carryover amounts separately on dashboard
- Set maximum carryover limits (e.g., 5 days)
- Update calculations to include carryover in available days

**Impact:** Match real-world employment practices

---

### Track Specific Dates of Time Off
**Priority:** Low
**Complexity:** High

**Description:** Track which specific dates were taken off instead of just total days per month.

**Requirements:**
- Create new time_off_days table (user_id, date, type, hours)
- Calendar view showing taken days
- Integration with salary_entries
- Calculate monthly totals from individual dates
- Support partial days (e.g., half-day off)

**Impact:** Detailed time off tracking and calendar integration

---

## Budget Sharing Enhancements

### Share via Link/Token
**Priority:** Low
**Complexity:** Medium

**Description:** Generate shareable links with access tokens for external users to view budgets without needing an account.

**Requirements:**
- Generate secure, expiring tokens for budget access
- Public view page for shared budgets
- Token management UI (revoke, regenerate)
- Optional password protection

**Impact:** Share budgets with accountants, family members outside the app

---

### Invite by Email
**Priority:** Low
**Complexity:** Medium

**Description:** Send email invitations to share budgets with specific people.

**Requirements:**
- Email invitation system
- Accept/decline workflow
- Link to existing user or create new account
- Notification when invitation is accepted

**Impact:** Easier onboarding for household members

---

### Read-only vs Edit Permissions
**Priority:** Low
**Complexity:** Medium

**Description:** Granular permission levels for shared budgets (view-only, edit items, full access).

**Requirements:**
- Permission levels enum (view, edit_items, full)
- Per-share permission setting
- UI to manage permissions
- Authorization checks throughout budget controllers

**Impact:** More control over shared budget access

---

### Undo/Restore from Activity Log
**Priority:** Low
**Complexity:** High

**Description:** Restore deleted items or revert changes using the PaperTrail activity log.

**Requirements:**
- Restore button next to delete events in activity log
- Revert changes for specific versions
- Confirmation dialog before restore
- Handle cascading restores (budget + items)

**Impact:** Recovery from accidental deletions

---

### Export to CSV/PDF
**Priority:** Medium
**Complexity:** Medium

**Description:** Export budget data to CSV or PDF format for external use.

**Requirements:**
- CSV export with all budget items
- PDF export with formatted layout
- Download buttons on budget show page
- Include summary statistics

**Impact:** Offline access, sharing with external tools

---

### Recurring Items
**Priority:** Medium
**Complexity:** Medium

**Description:** Mark budget items as recurring so they automatically copy to new months.

**Requirements:**
- Add recurring flag to budget_items
- Auto-populate recurring items when creating new budget
- UI to toggle recurring status
- Option to skip specific months

**Impact:** Reduce manual entry for fixed expenses

---

## Completed Features

These features have been implemented and merged:

- ✅ **Household Budget Planning** (PRs #24-27) - Monthly budget planning with dual currency support (CRC/USD), four expense categories with target percentages, household sharing, and Turbo Stream inline editing
- ✅ **Household/Shared View** (PR #20) - Create or join a household to view combined earnings with a partner
- ✅ **User Profile Editing** (PR #19) - Edit name, email, and password from Settings page
- ✅ **Vacation Over-Limit Warning** (PR #18) - Soft validation warning when taking more vacation days than earned, with acknowledgment checkbox
- ✅ **Configurable Vacation/Holiday Settings** (PR #17) - User settings page to customize vacation/holiday days per year
- ✅ **Charts/Graphs for Trends** (PR #12) - Savings breakdown stacked column chart on dashboard
- ✅ **Year Selector on Dashboard** (PR #9) - View historical data from previous years with year dropdown selector
- ✅ **Password Reset via Email** (PR #7) - Users can reset forgotten passwords via email
- ✅ **Time Off Tracking** (PR #6) - Track vacation/holiday days taken and adjust savings
- ✅ **Dashboard with Earnings Summary** (PR #4) - Main dashboard showing YTD earnings and savings
- ✅ **User Authentication** (PR #3) - Login, logout, registration

---

## Notes

- **Priority Levels:**
  - **High:** Important for core functionality or user experience
  - **Medium:** Valuable enhancement but not critical
  - **Low:** Nice-to-have for future consideration

- **Complexity Levels:**
  - **Low:** <4 hours of development
  - **Medium:** 4-8 hours of development
  - **High:** >8 hours of development

- Implementation should follow the established pattern:
  1. Brainstorm and create design document
  2. Create implementation plan with TDD approach
  3. Use subagent-driven development for execution
  4. Maintain near 100% test coverage
  5. Follow existing code patterns and conventions
