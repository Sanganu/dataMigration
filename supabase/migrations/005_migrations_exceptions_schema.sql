-- =========================================================
-- Exception handling
-- Postgress = set based update -provides a way to lock in email related issues
-- To handle all exceptions like Pl/SQL Cursors loop requires Row-by-row execution
-- then pgSQL Loop can be used
-- bad/unresolvable email values are logged with a reason, not silently dropped.
-- =========================================================

create table if not exists app.migration_exceptions (
    id            uuid primary key default gen_random_uuid(),
    source_table  text not null,
    source_id     text not null,
    reason_code   text not null,
    reason_detail text,
    raw_data      jsonb,
    logged_at     timestamptz not null default now()
);