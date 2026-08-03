select * from app.users order by email;
select reason_code, count(*) from app.migration_exceptions group by reason_code;