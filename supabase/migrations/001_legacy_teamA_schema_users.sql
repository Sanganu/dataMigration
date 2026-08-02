-- =========================================================
-- LEGACY — TEAM A
-- Text-based ids (email as de facto key), single full_name field,
-- single-letter role codes, deleted_at for soft-delete.
-- =========================================================

create schema if not exists legacy_team_a;

create table legacy_team_a.users (
    id           text primary key,   -- plain int-as-text, or occasionally an existing uuid
    email        text,
    full_name    text,               -- NOT split into first/last — Team A's convention
    role         text,               -- 'A' / 'C' / 'S' / occasionally garbage
    phone        text,
    deleted_at   timestamptz
);