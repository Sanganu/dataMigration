# dataMigration

Small demo showing how I'd merge two legacy user tables with different
schemas into one target table, without silently losing rows I can't
resolve.

The scenario: Team A and Team B each had their own `users` table before
a merger. Team A used mixed int/uuid ids stored as text, a single
`full_name` field, and single-letter role codes. Team B used real
UUIDs, split first/last names, and a different role vocabulary. Neither
side maps cleanly onto the other, so the target schema (`app.users`)
has to reconcile both.

This is a demo, not the actual client project — smaller, one entity
(users), built to show the pattern rather than a full migration.

## Schema differences

| | Team A (`legacy_team_a.users`) | Team B (`legacy_team_b.customers`) | Target (`app.users`) |
|---|---|---|---|
| id | text, mixed int / real uuid | uuid | uuid |
| name | single `full_name` | `first_name` + `last_name` | `first_name` + `last_name` |
| role | `'A'` / `'C'` / `'S'`, occasionally garbage | `'standard'` / `'premium'` / `'staff'` | enum: `ADMIN` / `CUSTOMER` / `STAFF` |
| soft delete | `deleted_at` | `is_active` (boolean) | `deleted_at` |
| extra | `phone` | `loyalty_points` | both |

## Files

```
supabase/migrations/
  001_legacy_teamA_schema_users.sql     source A
  002_legacy_teamB_schema_users.sql     source B
  003_target_schema_users.sql           app.users
  004_seed_users.sql                    messy seed data, both sources
  005_migrations_exceptions_schema.sql  exception log table
  006_merge_users.sql                   the actual merge
  007_validating_sqlqueries.sql         post-merge checks
```

## How the merge works (`006_merge_users.sql`)

1. Build a temp table `tmp_users` from Team A. If the id already looks
   like a UUID (regex check), keep it; otherwise generate a new one.
   Email gets `lower(trim(...))`'d. Unique index on email.
2. Insert Team B into the same temp table. If the email already
   exists (same person migrated from Team A), attach `legacy_b_id` to
   that row instead of creating a second one — this is the actual
   merge point.
3. Any row from either source with no usable email goes into
   `app.migration_exceptions` with a reason code and the raw row as
   jsonb. It doesn't get silently dropped, but it also doesn't block
   the rest of the migration.
4. `INSERT ... ON CONFLICT (email) DO UPDATE` into `app.users`. Name
   prefers Team A's `full_name` split on the first space, falls back
   to Team B. Role: Team A's letter code first, then Team B's
   `account_type`, then default to `CUSTOMER`. Phone and loyalty
   points each only exist on one side, so updates use `COALESCE` to
   avoid overwriting a real value with null.

Re-running `006` against a database that already has matching
`app.users` rows updates them instead of duplicating — that's what the
pre-inserted Ada Lovelace row in the seed data is there to check.

## Running it

```bash
git clone https://github.com/Sanganu/dataMigration.git
cd dataMigration
supabase start
supabase db reset   # runs 001-007 in order
```

Then check `app.users` and `app.migration_exceptions` in Studio
(`http://127.0.0.1:54323`), or run the two queries in
`007_validating_sqlqueries.sql` directly.

## Known gaps

I traced the merge against the seed data by hand rather than just
running it, and found a few things worth being upfront about instead
of pretending this is finished:

- **Garbage role codes don't get logged.** The seed data has a row
  with role `'X'`, which isn't `A`/`C`/`S`. It falls through both
  `CASE` branches and lands on the hardcoded `CUSTOMER` default —
  silently. `005`'s own comment says bad values get logged with a
  reason, but that's only true for missing emails. Role garbage just
  gets defaulted. I haven't decided yet if that's the right behavior
  or if it should also go to `migration_exceptions`.

- **`'premium'` maps to `ADMIN`.** In step 4, Team B's `account_type =
  'premium'` maps to the `ADMIN` role. That reads wrong — a paying
  customer tier becoming an administrative role — and I'm not sure
  yet if that's a leftover placeholder or if Team B's system actually
  conflated the two. Flagging it here instead of hiding it.

- **`007` isn't real validation, it's two queries.** It shows you the
  final table and an exception count, but it can't tell you whether
  every source row is actually accounted for. What it should have:
  `count(legacy_team_a) + count(legacy_team_b) - known_email_overlaps
  = count(app.users) + count(migration_exceptions)`. That reconciliation
  check doesn't exist yet.

- **No constraint on phone format.** The seed data has a row with
  phone `'not-a-phone'` on purpose, and it just gets copied through —
  `app.users.phone` is plain `text` with no check.

- **Name splitting is naive.** `full_name` is split on the first
  space, so a name like "Ada K. Lovelace" would put "K." into
  `last_name`. Fine for this seed data, not fine for real names.

- **Idempotency depends on `ON CONFLICT`, not on the temp table.**
  `tmp_users.user_id` for a row that's already in `app.users` (the
  pre-inserted Ada row) won't match the real `app.users.id` unless the
  legacy id happens to be the same UUID. The `ON CONFLICT ... DO
  UPDATE` clause doesn't touch `id`, so it works in this demo — but if
  a second table referencing `app.users.id` gets added later, it would
  need to look up the real id from `app.users` rather than trusting
  `tmp_users.user_id`.

None of these are hidden or fixed in a later migration — this is the
state of the code as it stands, and I'd rather the README say so than
have it look more finished than it is.

## Why set-based instead of a cursor loop

Team A's data is small and doesn't have interdependent business logic
between rows, so a single `INSERT ... ON CONFLICT` does the whole
merge without row-by-row processing. That's a genuinely different
situation from cases where you need per-row sequencing (e.g. an
insert-only, append-on-change source table, which is a different
project not shown here) — that kind of source needs a cursor, this
one doesn't.