# Foundation

Multi-tenant CRM and operations platform built with Ruby on Rails.

Foundation provides organization-scoped customers, sales pipeline (kanban), contacts, notes, offerings, and optional modules such as QuickBooks integration. Each tenant can enable the features they need.

## Features

- **Multi-org tenancy** — isolated data per organization
- **Sales pipeline** — kanban stages, leads, potentials, drag-and-drop
- **Customer hub** — profiles, contacts, activity and account notes
- **Offerings catalog** — configurable product/service slots per org
- **User management** — roles, invite-only registration
- **Optional modules** — QuickBooks, activity dashboard, and more per org

## Stack

Rails 7 · Ruby 3.2 · PostgreSQL · Devise · CanCanCan · Hotwire · Bootstrap 3 · esbuild · Sass

## Requirements

- Ruby 3.2+
- PostgreSQL
- Node.js and Yarn (for JavaScript and CSS builds)

## Getting started

```bash
git clone <repository-url>
cd foundation
bundle install
yarn install
bin/rails db:create db:migrate db:seed
bin/dev
```

Open [http://localhost:3000](http://localhost:3000).

For detailed setup, environment variables, and demo logins, see **[SETUP.md](SETUP.md)**.

## Development

Run the app with Rails and asset watchers:

```bash
bin/dev
```

Run tests:

```bash
bundle exec rspec
```

After editing SCSS:

```bash
npm run build:css
```

## Documentation

| Doc | Purpose |
|-----|---------|
| [SETUP.md](SETUP.md) | Local development setup |
| [.env.example](.env.example) | Environment variable template |
| [OPERATIONS_PLATFORM_PLAN.md](OPERATIONS_PLATFORM_PLAN.md) | Product roadmap and build checklist |
| [db/README.md](db/README.md) | Database migrations |

## License

Proprietary — all rights reserved unless otherwise noted.
