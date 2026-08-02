-- =========================================================
-- SEED DATA — messy AND overlapping across both sources
-- =========================================================

-- Team A
insert into legacy_team_a.users (id, email, full_name, role, phone, deleted_at) values
    ('a1b2c3d4-e5f6-4789-9abc-def012345678', 'ada@example.edu',      'Ada Lovelace',    'A', '+1 (555) 111-2222', null),
    ('1042',                                  'grace@example.edu',    'Grace Hopper',    'S', '555.222.3333',       null),
    ('1043',                                  'alan@example.edu',     'Alan Turing',     'C', 'not-a-phone',        null),
    ('1044',                                  null,                   'Edith Clarke',    'C', '+15553334444',       null),   -- no email: unresolvable against Team B
    ('1045',                                  '  Barbara@Example.edu  ', 'Barbara Liskov', 'X', null,               null),  -- messy email + bad role code
    ('1046',                                  'katherine@example.edu','Katherine Johnson','A', '5551234567',        now()); -- soft-deleted

-- Team B — note 'grace@example.edu' and 'katherine@example.edu' ALSO exist here:
-- these are the genuine merge cases (same person, two sources, different data).
insert into legacy_team_b.customers (id, email, first_name, last_name, account_type, loyalty_points, is_active) values
    (gen_random_uuid(), 'grace@example.edu',    'Grace',     'Hopper',   'staff',    120, true),   -- overlaps Team A: which phone/role wins?
    (gen_random_uuid(), 'katherine@example.edu','Katherine', 'Johnson',  'premium',  480, false),  -- overlaps Team A: Team A says deleted_at=now(), Team B says is_active=false — should agree
    (gen_random_uuid(), 'margaret@example.edu', 'Margaret',  'Hamilton','premium',  900, true);    -- Team B only, no Team A counterpart at all

-- Simulate: one user already migrated in a prior partial run
insert into app.users (id, email, first_name, last_name, role, phone) values
    ('11111111-1111-4111-8111-111111111111', 'ada@example.edu', 'Ada', 'Lovelace', 'ADMIN', '+15551112222');