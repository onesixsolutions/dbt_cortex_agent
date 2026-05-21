-- Fails if the comment is absent from the agent DDL.
-- Returns 0 rows on success (standard dbt test contract).

select 'comment missing from cortex_agent_test DDL' as error
where not contains(
  get_ddl(
    'cortex_agent',
    '{{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.CORTEX_AGENT_TEST'
  ),
  'Full integration test agent'
)
