# Foundation database setup

Fresh databases use **consolidated migrations** (no legacy CRM history).

## New environment

```bash
bin/rails db:create db:migrate db:seed
```

## Reset local dev (after pulling migration changes)

Stop the Rails server first (Postgres cannot drop DB while connections are open).

```bash
bin/rails db:drop db:create db:migrate db:seed
```

Optional: bootstrap the current week's pipeline stats row:

```bash
bin/rails create_weekly_stats_force
```

## Migration layout

| Batch | Files | Purpose |
|-------|-------|---------|
| Core (7) | `20260710100000` … `20260710107100` | Users, pipeline, orgs, tenant scoping |
| Post-core | `20260713130000`, `20260713150000`, `20260714100000`, `20260714120000` | QB tokens, nav modules, offerings, org `active` |
| **Discovery (3)** | `20260714140000`, `20260714170000`, `20260714180000` | WA SOS org settings, `discovery_businesses`, `discovery_sources` + `discovery_runs` |

Discovery was consolidated 2026-07-16 from 14 incremental migrations into the three files above; **2026-07-17** folded score, social, and check-status columns into `20260714170000_create_discovery_businesses` (removed five add-column migrations). Same final schema; fresh `db:migrate` only.

## Tables included

`users`, `lists`, `customers`, `contacts`, `notes`, `leads`, `offerings`, `stats`, `site_settings`, `qb_invoices`, `quickbooks_tokens`, `discovery_businesses`, `discovery_sources`, `discovery_runs`, Active Storage.

Agency-only tables from the old CRM fork (`tickets`, `messages`, `proposals`, `contracts`, `revenues`, `intakes`, `passcodes`, `todos`) are **not** recreated.

## Existing databases with old migration history

Do not run new migrations on top of the old Discovery chain (pre-consolidation timestamps `20260714150000` … `20260716233000`). Drop and recreate (backup first if you need data).
