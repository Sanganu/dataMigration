-- =========================================================
-- LEGACY — TEAM B
-- UUID ids already, first/last name split, different role
-- vocabulary, loyalty_points (Team A has no equivalent),
-- is_active instead of deleted_at.
-- =========================================================

create schema if not exists legacy_team_b;

create table legacy_team_b.customers (
    id             uuid primary key default gen_random_uuid(),
    email          text,
    first_name     text,
    last_name      text,
    account_type   text,             -- 'standard' / 'premium' / 'staff'
    loyalty_points int,
    is_active      boolean default true
);