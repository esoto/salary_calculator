# Documentation

This directory contains design documents, implementation plans, and feature tracking for the Salary Calculator application.

## Structure

### `/PENDING_FEATURES.md`
Comprehensive list of features that have been identified but not yet implemented, including:
- Priority and complexity estimates
- Requirements and impact analysis
- Organized by category (Dashboard, Salary Entry, Time Off, User/Auth)

### `/plans/`
Design documents for implemented features. These documents describe the high-level architecture, decisions, and approach for each feature.

**Active design documents:**
- `2026-01-06-salary-entry-design.md` - Core salary tracking functionality
- `2026-01-06-user-authentication-design.md` - User login and registration
- `2026-01-07-dashboard-design.md` - Main dashboard with earnings summary
- `2026-01-07-time-off-tracking-design.md` - Vacation and holiday tracking
- `2026-01-08-password-reset-completion-design.md` - Password reset via email

### `/plans/completed/`
Implementation plans that were executed and are now archived. These detailed step-by-step guides were used during TDD implementation but are kept for reference:
- `2026-01-06-salary-entry-implementation.md`
- `2026-01-06-user-authentication-implementation.md`
- `2026-01-07-dashboard-implementation.md`
- `2026-01-07-time-off-tracking-implementation.md`
- `2026-01-08-password-reset-completion-implementation.md`

## Feature Development Workflow

When implementing a new feature from `PENDING_FEATURES.md`:

1. **Brainstorm** - Use brainstorming to explore approaches and make design decisions
2. **Design Document** - Create `YYYY-MM-DD-feature-name-design.md` in `/plans/`
3. **Implementation Plan** - Create detailed TDD implementation plan
4. **Execute** - Use subagent-driven development to implement following TDD
5. **Review** - Code review, ensure tests pass, RuboCop clean
6. **Merge** - Create PR and merge to develop
7. **Archive** - Move implementation plan to `/plans/completed/`
8. **Update** - Remove from `PENDING_FEATURES.md`

## Principles

- **TDD Required** - Write tests first, always
- **100% Test Coverage** - Per CLAUDE.md requirements
- **Document Decisions** - Design docs explain "why", not just "what"
- **Clean Code** - Follow RuboCop style guide
- **Security First** - Consider security implications in every feature
