# Foundation – Project Setup Guide

*For future you: how this project works and how to get it running.*

---

## Project Overview

**Foundation** is a Rails 7 app with a **jsbundling + esbuild** frontend. Unlike simpler Rails apps that use Importmap (no build step), this project requires **Node.js**, **Yarn**, and a **build step** for JavaScript and CSS.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Backend | Rails 7.0.4, Ruby 3.1.2 |
| Database | PostgreSQL |
| JS bundling | **jsbundling-rails** + **esbuild** |
| CSS | **cssbundling-rails** + **sass** |
| Frontend | Stimulus, Turbo, Bootstrap, SortableJS, InteractJS |

---

## Version Reference

*Use these versions when setting up a new machine or comparing to future installs.*

### System / Runtime

| Tool | Version | Check with |
|------|---------|------------|
| Ruby | **3.1.2** | `ruby -v` |
| Node.js | **v20+** (Heroku: 24.13.0) | `node -v` |
| Yarn | **1.22.x** (Heroku: 1.22.22) | `yarn -v` |
| PostgreSQL | 14+ recommended | `psql --version` |

### Rails & Key Gems (from Gemfile.lock)

| Gem | Version |
|-----|---------|
| rails | 7.0.4 |
| puma | 3.12.6 |
| pg | 1.5.3 |
| devise | 4.9.2 |
| foreman | 0.89.1 |

### Key npm Packages (from yarn.lock)

| Package | Version |
|---------|---------|
| esbuild | 0.18.0 |
| esbuild-rails | 1.0.7 |
| sass | 1.63.3 |
| @hotwired/stimulus | ^3.2.1 |
| @hotwired/turbo-rails | ^7.3.0 |
| bootstrap | ^3.4.1 |

### Quick Version Check

```bash
ruby -v    # expect: ruby 3.1.2
node -v    # expect: v20.x or v24.x
yarn -v    # expect: 1.22.x
bundle exec rails -v   # expect: Rails 7.0.4
```

---

## Why This Setup?

- **jsbundling-rails** = npm packages, bundling, tree-shaking, minification
- **Importmap** (used in reviewbox7) = no build step, loads from CDN, simpler but limited

This project uses the more capable setup for dynamic JS and richer frontend behavior.

---

## Local Setup (Fresh Machine / New Clone)

### 1. Prerequisites

- **Ruby 3.1.2** (rbenv, rvm, or asdf)
- **Node.js** (v20+; Heroku uses 24.13.0)
- **Yarn** (v1.22.x; Heroku uses 1.22.22)
- **PostgreSQL**

### 2. Install Yarn (if missing)

```bash
# Option A: Homebrew
brew install yarn

# Option B: npm (if Node is installed)
npm install -g yarn
```

### 3. Project Setup

```bash
cd Foundation

# Ruby gems
bundle install

# Node dependencies (required – creates node_modules)
yarn install

# Database
bin/rails db:create db:migrate
```

### 4. Start the Server

**Recommended (development):**
```bash
bin/dev
```
Starts Rails server + JS watcher + CSS watcher. Use this for local dev so JS/CSS rebuild on save.

**Rails server only (no watchers):**
```bash
bin/rails server
# or
bundle exec rails server
# or (short form)
bundle exec rails s
```
Use when you don't need live JS/CSS rebuilds. You must run `yarn build` and `yarn build:css` manually after changes.

**When to use `bundle exec`:**
- `bundle exec rails ...` – runs Rails within the project's Gemfile
- `bundle exec rake ...` – same for Rake tasks
- `bin/rails` and `bin/rake` already use the project bundle, so `bundle exec` is usually optional
- Use `bundle exec` if you get "wrong gem version" or "command not found" errors

**About `exec` in bin/dev:**
- `bin/dev` runs `exec bundle exec foreman start -f Procfile.dev`
- `exec` replaces the current shell with foreman, so Ctrl+C stops all processes (Rails, JS watcher, CSS watcher) cleanly

---

## Setup Checklist (Dummy List)

Use this list when setting up from scratch:

- [ ] Install Ruby 3.1.2 (`rbenv install 3.1.2` or `rvm install 3.1.2`)
- [ ] Install Node.js (v20+)
- [ ] Install Yarn (`brew install yarn` or `npm install -g yarn`)
- [ ] Install PostgreSQL
- [ ] Clone the repo and `cd Foundation`
- [ ] Run `bundle install`
- [ ] Run `yarn install`
- [ ] Run `bin/rails db:create db:migrate`
- [ ] Run `bin/dev` to start the app
- [ ] Open http://localhost:3000

---

## One-Off Builds (No Watchers)

```bash
yarn build          # JS only
yarn build:css      # CSS only
```

Or for production assets:

```bash
bundle exec rails assets:precompile
```

---

## Heroku Deployment

- **Buildpack**: `heroku/ruby` only (Node + Yarn are bundled by the Ruby buildpack)
- **Build flow**: `bundle install` → `rake assets:precompile` → runs `yarn install`, `yarn build`, `yarn build:css`
- **Lock file**: Heroku uses `yarn.lock` (Yarn takes precedence over `package-lock.json`)

---

## Environment variables

Copy `.env.example` to `.env` for local secrets.

### QuickBooks ENV (server-wide — one Intuit app per host)

| Variable | Still needed? | Purpose |
|----------|---------------|---------|
| `QB_CLIENT_ID` | Yes | Sandbox Intuit app client ID |
| `QB_CLIENT_SECRET` | Yes | Sandbox Intuit app secret |
| `QB_REDIRECT_URI` | Yes | OAuth callback for sandbox (e.g. `http://localhost:3000/oauth/callback`) |
| `QB_CLIENT_ID_PRO` | Yes | Production Intuit app client ID |
| `QB_CLIENT_SECRET_PRO` | Yes | Production Intuit app secret |
| `QB_REDIRECT_URI_PRO` | Yes | OAuth callback on staging/production host |
| `QB_COMPANY_ID` | **No** | Replaced by per-org `realm_id` in Settings → QuickBooks |
| `QB_COMPANY_ID_SANDBOX` | **No** | Replaced by per-org `sandbox_realm_id` / OAuth |

Per-org: **Settings → QuickBooks** (switch org first). Save sandbox/production realm IDs, environment toggle, connect/disconnect. Module visibility: Organizations → `quickbooks_enabled`.

See `OPERATIONS_PLATFORM_PLAN.md` §19.

## Key Files

| File | Purpose |
|------|---------|
| `package.json` | Node deps, build scripts |
| `yarn.lock` | Locked Yarn dependency versions |
| `esbuild.config.js` | JS bundling config (supports `--watch`) |
| `Procfile.dev` | Foreman processes for `bin/dev` |
| `app/javascript/` | JS source (Stimulus controllers, etc.) |
| `app/assets/stylesheets/` | SCSS source |
| `app/assets/builds/` | Compiled JS/CSS output |

---

## Troubleshooting

### "yarn: command not found"
- Install Yarn: `brew install yarn` or `npm install -g yarn`

### "Cannot find module 'esbuild-rails'"
- Run `yarn install` in the project root (creates `node_modules`)

### "bin/dev" exits immediately / JS watcher dies
- esbuild.config.js must use `context()` + `ctx.watch()` when `--watch` is passed (already fixed)

### package-lock.json vs yarn.lock warning
- Both exist if npm was used at some point. Using Yarn only: `rm package-lock.json` to silence the warning.

### Rails binstub warning
```bash
bundle config --delete bin
rails app:update:bin
```

---

## Comparison: Foundation vs reviewbox7

| | Foundation | reviewbox7 |
|---|------------|------------|
| JS | jsbundling + esbuild | importmap-rails |
| CSS | cssbundling + sass | sassc-rails |
| Build step | Yes (yarn build) | No |
| Yarn required | Yes | No (optional) |
| node_modules | Yes | Minimal |

---

## Quick Reference

```bash
# First-time setup
bundle install && yarn install && bin/rails db:create db:migrate

# Run app
bin/dev

# Automated QA (§12.11)
RAILS_ENV=test bin/rails db:drop db:create db:schema:load
bundle exec rspec

# One-off JS build
yarn build

# One-off CSS build
yarn build:css
```

## Deploy checklist (§13)

Before staging/production:

1. Set env vars from `.env.example` (`SECRET_KEY_BASE`, `DATABASE_URL`, mailer)
2. Deploy uses `Procfile` — `release: bundle exec rails db:migrate`
3. Seed once: `bin/rails db:seed` (creates superadmin + demo orgs)
4. Schedule **every Monday**: `rake create_weekly_stats` (Heroku Scheduler, cron, etc.)
5. Post-deploy smoke: log in, open kanban, create a test lead, confirm stats row exists
6. Run `bundle exec rspec` in CI or locally before promote

See `OPERATIONS_PLATFORM_PLAN.md` **§13** for full detail.
