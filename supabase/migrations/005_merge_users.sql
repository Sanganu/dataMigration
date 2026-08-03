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

insert into app.users (id, email, first_name, last_name, role, phone, loyalty_points, deleted_at)
select
    tu.user_id,
    tu.email,
    coalesce(split_part(lca.full_name, ' ', 1), lcb.first_name),
    coalesce(trim(substring(lca.full_name from position(' ' in lca.full_name))), lcb.last_name),
    coalesce(
        case
            when upper(trim(lca.role)) = 'A' then 'ADMIN'
            when upper(trim(lca.role)) = 'S' then 'STAFF'
            when upper(trim(lca.role)) = 'C' then 'CUSTOMER'
        end,
        case
            when lower(trim(lcb.account_type)) = 'standard' then 'CUSTOMER'
            when lower(trim(lcb.account_type)) = 'premium' then 'ADMIN'
            when lower(trim(lcb.account_type)) = 'staff' then 'STAFF'
        end,
        'CUSTOMER'
    )::app.user_role,
    lca.phone,
    lcb.loyalty_points,
    case
        when lca.deleted_at is not null then lca.deleted_at
        when lcb.is_active = false then now()
        else null
    end
from tmp_users tu
left join legacy_team_a.users lca on tu.legacy_a_id = lca.id
left join legacy_team_b.customers lcb on tu.legacy_b_id = lcb.id
where tu.email is not null
on conflict (email) do update set
    first_name     = excluded.first_name,
    last_name      = excluded.last_name,
    role           = excluded.role,
    phone          = coalesce(excluded.phone, app.users.phone),
    loyalty_points = coalesce(excluded.loyalty_points, app.users.loyalty_points),
    deleted_at     = excluded.deleted_at;

commit;

select * from app.users;

