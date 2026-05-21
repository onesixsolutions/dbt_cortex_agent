-- Fails if dbt_demo_role has not been granted USAGE on cortex_agent_test.
-- Returns 0 rows on success (standard dbt test contract).

select 'dbt_demo_role not granted usage on cortex_agent_test' as error
where not exists (
  select 1
  from {{ target.database }}.information_schema.object_privileges
  where object_schema  = upper('{{ target.schema }}_INTEGRATION_TESTS')
    and object_name    = 'CORTEX_AGENT_TEST'
    and privilege_type = 'USAGE'
    and grantee        = 'DBT_DEMO_ROLE'
)
