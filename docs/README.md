# Documentation

This directory contains design documents, implementation plans, and feature tracking for the Salary Calculator application.

## Structure

### `/PENDING_FEATURES.md`
List of features that have been identified but not yet implemented, including:
- Priority and complexity estimates
- Requirements and impact analysis

### `/plans/completed/`
Design documents and implementation plans for all completed features:
- Salary entry tracking
- User authentication
- Dashboard with earnings summary
- Time off tracking
- Password reset via email
- Year selector
- Savings charts
- Configurable savings settings
- Vacation over-limit warning
- User profile editing
- Household shared view

## Feature Development Workflow

When implementing a new feature from `PENDING_FEATURES.md`:

1. **Brainstorm** - Use brainstorming to explore approaches and make design decisions
2. **Design Document** - Create `YYYY-MM-DD-feature-name-design.md` in `/plans/`
3. **Implementation Plan** - Create detailed TDD implementation plan
4. **Execute** - Use subagent-driven development to implement following TDD
5. **Review** - Code review, ensure tests pass, RuboCop clean
6. **Merge** - Create PR and merge to develop
7. **Archive** - Move plans to `/plans/completed/`
8. **Update** - Mark as completed in `PENDING_FEATURES.md`

## Principles

- **TDD Required** - Write tests first, always
- **100% Test Coverage** - Per CLAUDE.md requirements
- **Document Decisions** - Design docs explain "why", not just "what"
- **Clean Code** - Follow RuboCop style guide
- **Security First** - Consider security implications in every feature
