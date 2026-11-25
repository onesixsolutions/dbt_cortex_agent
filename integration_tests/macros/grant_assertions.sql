-- Helpers for the grant integration tests.
--
-- SHOW GRANTS cannot be used as a subquery, so each object under test has a "*_grants" model
-- that captures SHOW GRANTS ON <object> into a table (see capture_show_grants below). The
-- singular tests then assert on those tables with expect_grant / expect_no_grant.

-- Body of a grants capture model. The model's pre_hook must run the SHOW GRANTS statement;
-- result_scan(last_query_id()) then reads that result set on the same connection.
-- SHOW output column names are lower-case, so they have to be double-quoted.
{% macro capture_show_grants() %}
select
    "privilege"    as privilege,
    "granted_on"   as granted_on,
    "granted_to"   as granted_to,
    "grantee_name" as grantee_name
from table(result_scan(last_query_id()))
{% endmacro %}

-- Returns one error row when `role` does NOT hold `privilege` in the capture table.
{% macro expect_grant(capture_relation, privilege, role, label) %}
select '{{ label }}: expected {{ privilege | upper }} to be granted to role {{ role | upper }}' as error
where not exists (
    select 1
    from {{ capture_relation }}
    where upper(privilege)    = '{{ privilege | upper }}'
      and upper(granted_to)   = 'ROLE'
      and upper(grantee_name) = '{{ role | upper }}'
)
{% endmacro %}

-- Returns one error row when `role` DOES hold `privilege` in the capture table.
{% macro expect_no_grant(capture_relation, privilege, role, label) %}
select '{{ label }}: expected {{ privilege | upper }} NOT to be granted to role {{ role | upper }}' as error
where exists (
    select 1
    from {{ capture_relation }}
    where upper(privilege)    = '{{ privilege | upper }}'
      and upper(granted_to)   = 'ROLE'
      and upper(grantee_name) = '{{ role | upper }}'
)
{% endmacro %}
