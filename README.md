# Salary Calculator

A Ruby on Rails application for tracking freelance earnings, calculating savings for Mexican labor benefits (aguinaldo, vacation premium, holiday pay), and managing household finances.

## Features

- **Salary Entry Tracking** - Log hours worked and hourly rate per month
- **Automatic Savings Calculations** - Computes aguinaldo, vacation, and holiday savings based on Mexican labor law
- **Time Off Tracking** - Track vacation and holiday days taken with over-limit warnings
- **Dashboard** - View year-to-date earnings, savings breakdown, and trends
- **Savings Charts** - Visual breakdown of savings by category
- **Configurable Settings** - Customize vacation/holiday days per year and hours per day
- **Household Sharing** - Create or join a household to view combined earnings with a partner
- **User Authentication** - Secure login, registration, and password reset via email

## Tech Stack

- **Ruby** 3.4.1
- **Rails** 8.1
- **PostgreSQL** 17 - Database
- **TailwindCSS** 4 - Styling
- **Hotwire (Turbo + Stimulus)** - Frontend interactivity
- **Chartkick** - Charts and graphs
- **Solid Queue** - Background jobs (in-process via Puma)
- **Solid Cache** - Caching
- **Solid Cable** - WebSockets
- **RSpec** - Testing framework

## Getting Started

### Prerequisites

- Ruby 3.4.1
- PostgreSQL
- Node.js (for TailwindCSS)

### Installation

```bash
# Clone the repository
git clone https://github.com/esoto/salary_calculator.git
cd salary_calculator

# Install dependencies
bundle install

# Setup database
bin/rails db:setup

# Build CSS
bin/rails tailwindcss:build

# Run the server
bin/rails server
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec
```

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Run Brakeman security scanner
bundle exec brakeman
```

## Deployment

Deployed on a Hetzner VPS via [Kamal](https://kamal-deploy.org/) with Docker Hub.

- **URL**: https://salary-calc.estebansoto.dev
- **Server**: Hetzner CX23 (shared with [personal blog](https://blog.estebansoto.dev))
- **Database**: Shared PostgreSQL 17 container
- **SSL**: Let's Encrypt via kamal-proxy (auto-renewal)
- **Monitoring**: UptimeRobot

### Prereqs

- [1Password CLI](https://developer.1password.com/docs/cli/get-started/): `brew install --cask 1password-cli`
- Biometric unlock enabled (1Password app → Settings → Developer → Integrate with 1Password CLI)
- Access to the `Salary Calculator` item in the `Personal Brand` 1Password vault

### Deploy

```bash
kamal deploy              # Deploy latest commit
kamal rollback            # Rollback to previous version
kamal app logs -f         # Tail production logs
kamal console             # Rails console on server
kamal shell               # Bash on server
```

### Configuration

- `config/deploy.yml` - Kamal deployment config
- `.kamal/secrets` - Uses `op read` references; secrets are fetched from 1Password at deploy time (no raw values in the repo)

## Documentation

See the [docs/](docs/) folder for:
- Feature design documents
- Implementation plans
- Development workflow guidelines

## License

This project is private and not licensed for public use.
