-- =========================================================
-- TARGET (post-merge) — app.users
-- The reconciled shape both teams' data has to fit into.
-- =========================================================

create schema if not exists app;

create type app.user_role as enum ('ADMIN', 'CUSTOMER', 'STAFF');

create table app.users (
    id             uuid primary key default gen_random_uuid(),
    email          text unique not null,
    first_name     text not null,
    last_name      text not null default '',
    role           app.user_role not null default 'CUSTOMER',
    phone          text,                    -- only Team A ever had this
    loyalty_points int,                     -- only Team B ever had this
    deleted_at     timestamptz,             -- reconciled from Team A's deleted_at AND Team B's is_active
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);