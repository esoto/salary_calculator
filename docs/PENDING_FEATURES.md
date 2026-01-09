# Pending Features

This document tracks features that have been identified but not yet implemented.

**Last Updated:** 2026-01-08

---

## Dashboard Enhancements

### Year Selector on Dashboard
**Priority:** Medium
**Complexity:** Medium

**Description:** Add ability to view previous years' data on the dashboard. Currently only shows current year YTD.

**Requirements:**
- Year dropdown selector in dashboard header
- Filter all dashboard calculations by selected year
- Default to current year
- Show available years based on user's salary entries

**Impact:** Better historical data analysis

---

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

### Configurable Vacation/Holiday Settings
**Priority:** Medium
**Complexity:** Medium

**Description:** Allow users to customize vacation and holiday days per year instead of hardcoded values (currently 18 vacation, 10 holidays).

**Requirements:**
- User settings page with configuration form
- Store vacation_days_per_year and holiday_days_per_year per user
- Update calculations to use user-specific values
- Migration to add columns to users table
- Default values: 18 vacation, 10 holidays

**Impact:** Support different employment contracts and countries

---

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

### Prevent Taking More Days Than Earned
**Priority:** High
**Complexity:** Low

**Description:** Add validation to prevent users from taking more vacation/holiday days than they've earned.

**Requirements:**
- Add model validation: `vacation_days_taken <= vacation_days_earned`
- Calculate days earned up to current entry's month
- Show clear error message when validation fails
- Consider allowing negative balance with warning (for advance time off)

**Impact:** Prevent data entry errors

---

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

## User/Authentication Enhancements

### Household/Shared View
**Priority:** Low
**Complexity:** High

**Description:** Allow multiple users to access shared salary data for household financial planning.

**Requirements:**
- Household model with multiple users
- Invitation system for adding family members
- Permission levels (owner, editor, viewer)
- Aggregate household view combining multiple users
- Privacy settings for individual entries

**Impact:** Family financial planning

---

### User Profile Editing
**Priority:** Medium
**Complexity:** Low

**Description:** Allow users to update their profile information (name, email, preferences).

**Requirements:**
- Profile page with edit form
- Update name, email_address
- Email confirmation for email changes
- Password change functionality (update existing password, not reset)
- Profile route and navigation link

**Impact:** Basic user account management

---

## Completed Features

These features have been implemented and merged:

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
