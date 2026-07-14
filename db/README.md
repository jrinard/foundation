# Foundation database setup

Fresh databases use **7 consolidated migrations** (no legacy CRM history).

## New environment

```bash
bin/rails db:create db:migrate db:seed
```

## Reset local dev (after pulling migration changes)

```bash
bin/rails db:drop db:create db:migrate db:seed
```

Optional: bootstrap the current week's pipeline stats row:

```bash
bin/rails create_weekly_stats_force
```

## Tables included

`users`, `lists`, `customers`, `contacts`, `notes`, `leads`, `offerings`, `stats`, `site_settings`, `qb_invoices`, `quickbooks_tokens`, Active Storage.

Agency-only tables from the old CRM fork (`tickets`, `messages`, `proposals`, `contracts`, `revenues`, `intakes`, `passcodes`, `todos`) are **not** recreated.

## Existing databases with old migration history

Do not run new migrations on top of the old chain. Drop and recreate (backup first if you need data).
