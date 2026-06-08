-- Fails if the profile display_name is absent from the agent DDL.
-- Returns 0 rows on success (standard dbt test contract).
-- depends_on: {{ ref('cortex_agent_test') }}

select 'profile display_name missing from cortex_agent_test DDL' as error
where not contains(
  get_ddl(
    'cortex_agent',
    '{{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.CORTEX_AGENT_TEST'
  ),
  'Full Test Agent'
)
