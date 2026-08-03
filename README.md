I evaluated the repo at https://github.com/Sanganu/dataMigration. Here's a quick assessment, followed by a professional README you can drop straight into `README.md`.

### Evaluation summary
- **What it is:** A Supabase (Postgres) demo that reconciles two legacy user datasets (Team A + Team B) into a unified target schema `app.users`, with an exception-logging pattern for unresolvable rows.
- **Structure:** Clean, numbered migrations under `supabase/migrations/` (001–007) + `config.toml` + ad-hoc validation snippets. Solid separation of legacy schemas, target schema, seed, exceptions, and merge logic.
- **Strengths:** Clear naming, comments in SQL explain intent, realistic messy data (bad emails, garbage role codes, soft-delete conflicts, overlapping identities), set-based merge with `ON CONFLICT`, exceptions table instead of silently dropping rows.
- **Gaps / suggestions:**
  - No README content — reviewers cannot tell what the project does.
  - `snippets/Untitled query 481.sql` etc. should be renamed to something descriptive (e.g., `validate_merge.sql`).
  - Consider a `rollback.sql` / idempotency notes.
  - Role mapping in `006_merge_users.sql` maps Team B `'premium' → ADMIN` — this looks like a bug (premium customers are usually `CUSTOMER`, not admins). Worth calling out.
  - Deleted-state reconciliation currently prefers Team A's `deleted_at`; document the precedence rule.
  - No tests / assertions beyond two select statements in `007_validating_sqlqueries.sql`.

---

### Proposed `README.md`

````markdown
# dataMigration

A Supabase / PostgreSQL reference project that demonstrates how to **merge two legacy user datasets with conflicting schemas into a single, reconciled target schema** — safely, idempotently, and with full exception tracking.

The project simulates a realistic post-acquisition or post-reorg scenario where **Team A** and **Team B** each ran their own user store with different conventions, and the business now needs one canonical `app.users` table.

---

## Table of contents
- [Scenario](#scenario)
- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Migration pipeline](#migration-pipeline)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Validating the merge](#validating-the-merge)
- [Design decisions](#design-decisions)
- [Known issues / TODO](#known-issues--todo)
- [License](#license)

---

## Scenario

| Source | Schema | Key style | Name field | Role vocab | Soft-delete signal | Extra |
|---|---|---|---|---|---|---|
| `legacy_team_a.users` | Legacy A | `text` (mixed int / uuid) | single `full_name` | `A` / `C` / `S` (+ garbage) | `deleted_at` | `phone` |
| `legacy_team_b.customers` | Legacy B | `uuid` | `first_name` + `last_name` | `standard` / `premium` / `staff` | `is_active = false` | `loyalty_points` |
| `app.users` | **Target** | `uuid` | `first_name` + `last_name` | enum `ADMIN` / `CUSTOMER` / `STAFF` | `deleted_at` | both `phone` and `loyalty_points` |

The seed data intentionally includes:
- Users that exist in **both** sources (true merge cases, e.g. `grace@example.edu`, `katherine@example.edu`).
- Users with **missing or malformed emails** (unresolvable → logged as exceptions).
- Users with **garbage role codes** (`'X'`) that must fall back to a safe default.
- A **pre-migrated row** in `app.users` (idempotency test — the pipeline must not duplicate `ada@example.edu`).
- Conflicting soft-delete signals between Team A (`deleted_at`) and Team B (`is_active`).

---

## Architecture

```
┌──────────────────────┐        ┌──────────────────────┐
│ legacy_team_a.users  │        │ legacy_team_b.customers │
│  (text ids, messy)   │        │  (uuid ids, split name) │
└──────────┬───────────┘        └───────────┬──────────┘
           │                                │
           │   normalize + crosswalk        │
           ▼                                ▼
        ┌───────────────── tmp_users ─────────────────┐
        │  unique per lower(trim(email))              │
        │  carries legacy_a_id + legacy_b_id          │
        └──────────────────────┬──────────────────────┘
                               │
             ┌─────────────────┴─────────────────┐
             │                                   │
             ▼                                   ▼
   ┌──────────────────┐              ┌────────────────────────────┐
   │   app.users      │              │ app.migration_exceptions   │
   │ (canonical)      │              │ (MISSING_EMAIL, etc.)      │
   └──────────────────┘              └────────────────────────────┘
```

---

## Repository layout

```
.
├── README.md
├── .gitignore
└── supabase/
    ├── config.toml                 # Local Supabase CLI configuration
    ├── migrations/
    │   ├── 001_legacy_teamA_schema_users.sql       # source A schema
    │   ├── 002_legacy_teamB_schema_users.sql       # source B schema
    │   ├── 003_target_schema_users.sql             # canonical app.users
    │   ├── 004_seed_users.sql                      # realistic messy seed data
    │   ├── 005_migrations_exceptions_schema.sql    # exception log table
    │   ├── 006_merge_users.sql                     # the actual merge pipeline
    │   └── 007_validating_sqlqueries.sql           # post-merge sanity checks
    └── snippets/                    # ad-hoc SQL used during development
```

---

## Migration pipeline

The merge logic in `006_merge_users.sql` runs in four deterministic steps:

1. **Crosswalk from Team A** — Build a temporary `tmp_users` table. Preserve Team A's UUIDs when the id already looks like a UUID; otherwise mint a fresh one. Normalize email to `lower(trim(...))`. Enforce a unique index on `email`.
2. **Crosswalk from Team B** — Insert Team B rows into the same `tmp_users`. On email conflict, attach `legacy_b_id` to the existing row (this is where a "same person, two sources" record is recognized as a single identity).
3. **Log unresolvable rows** — Any row from either source with a null / empty email is inserted into `app.migration_exceptions` with `reason_code = 'MISSING_EMAIL'` and the raw source row stored as `jsonb`. Nothing is silently dropped.
4. **Merge into `app.users`** — Set-based `INSERT ... ON CONFLICT (email) DO UPDATE`:
   - **Name:** prefer Team A's `full_name` split on the first space; fall back to Team B's `first_name` / `last_name`.
   - **Role:** map Team A's single-letter code → enum; else map Team B's `account_type` → enum; else default to `CUSTOMER`.
   - **Phone:** only Team A has it; carried through, but never overwritten with `NULL` on update.
   - **Loyalty points:** only Team B has it; same non-null-preserving rule.
   - **`deleted_at`:** Team A's `deleted_at` wins; if it's null but Team B says `is_active = false`, stamp `now()`.

The pipeline is **idempotent**: re-running the merge against an `app.users` that already contains matching rows updates them in place rather than duplicating.

---

## Prerequisites

- [Docker](https://www.docker.com/) (required by Supabase local dev)
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) `>= 1.x`
- PostgreSQL client (`psql`) for running validation queries (optional)

---

## Getting started

```bash
# 1. Clone
git clone https://github.com/Sanganu/dataMigration.git
cd dataMigration

# 2. Start a local Supabase stack (Postgres 17, Studio on :54323, API on :54321)
supabase start

# 3. Apply all migrations in order (001 → 007)
supabase db reset
```

`supabase db reset` will:
1. Drop and recreate the local database.
2. Run every file in `supabase/migrations/` in filename order.
3. Leave you with:
   - `legacy_team_a.users` and `legacy_team_b.customers` populated with seed data
   - `app.users` populated with the merged, reconciled result
   - `app.migration_exceptions` populated with any rows that could not be merged

Open Supabase Studio at [http://127.0.0.1:54323](http://127.0.0.1:54323) to browse the resulting tables.

---

## Validating the merge

Run the queries in `007_validating_sqlqueries.sql`:

```sql
-- Final merged users
select * from app.users order by email;

-- Exception summary by reason code
select reason_code, count(*)
from app.migration_exceptions
group by reason_code;
```

Expected observations after a clean run:
- Ada Lovelace appears **once** even though she was pre-inserted in `app.users` and also existed in Team A (idempotency).
- Grace Hopper and Katherine Johnson each appear **once**, combining Team A's phone with Team B's loyalty points.
- Margaret Hamilton appears from Team B only.
- Edith Clarke (Team A, no email) shows up in `app.migration_exceptions` with `MISSING_EMAIL`, **not** in `app.users`.

---

## Design decisions

- **Set-based over row-by-row.** The pipeline uses a single `INSERT ... ON CONFLICT` rather than a PL/pgSQL cursor loop. This is intentional: Postgres is optimized for set-based work, and it composes cleanly with the exceptions table for anything that can't be handled declaratively. A cursor-based variant would be appropriate only if per-row business rules were required.
- **Email as the merge key.** Legacy ids are incompatible between sources, so the reconciled identity is anchored on `lower(trim(email))`. Rows without an email cannot be merged and are diverted to exceptions.
- **Exceptions, not silent drops.** Every unresolvable row is logged with `source_table`, `source_id`, `reason_code`, and the raw row as `jsonb` — auditable and re-processable.
- **Precedence rules.** Team A wins for `phone` and `deleted_at`; Team B wins for `loyalty_points`. Names prefer Team A only because Team A carries the "richer" free-form field. This is documented so future contributors can change it deliberately.



## Known issues / TODO


- [ ] Split of `full_name` uses a naïve first-space split — names like `"Ada K. Lovelace"` land the middle initial into `last_name`.
- [ ] Rename files in `supabase/snippets/` from `Untitled query NNN.sql` to descriptive names.
- [ ] Add a `rollback.sql` that truncates `app.users` and `app.migration_exceptions` for repeatable local testing without a full `db reset`.
- [ ] Add automated assertion tests (e.g. `pgTAP`) covering: idempotency, exception logging, role mapping, deleted-state reconciliation.
