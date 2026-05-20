-- Fails if the profile display_name is absent from the full agent DDL.
-- Returns 0 rows on success (standard dbt test contract).

select 'profile display_name missing from cortex_agent_full DDL' as error
where not contains(
  get_ddl(
    'agent',
    '{{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.CORTEX_AGENT_FULL'
  ),
  'Full Test Agent'
)
