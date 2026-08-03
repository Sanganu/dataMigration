create temp table tmp_users as
select
    case
        when lega.id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then lega.id::uuid
        else gen_random_uuid()
    end as user_id,
    lega.id::text as legacy_a_id,
    null::uuid as legacy_b_id,
    case
        when lega.email is null or trim(lega.email) = '' then null
        else lower(trim(lega.email))
    end as email
from legacy_team_a.users lega;

create unique index on tmp_users(email);

insert into tmp_users (user_id, legacy_a_id, legacy_b_id, email)
select
    case
        when legb.id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then legb.id::uuid
        else gen_random_uuid()
    end as user_id,
    null as legacy_a_id,
    legb.id as legacy_b_id,
    case
        when legb.email is null or trim(legb.email) = '' then null
        else lower(trim(legb.email))
    end as email
from legacy_team_b.customers legb
on conflict (email) do update set
    legacy_b_id = excluded.legacy_b_id;

select * from users;