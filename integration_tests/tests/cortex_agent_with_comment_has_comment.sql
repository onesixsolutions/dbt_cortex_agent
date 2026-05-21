-- Fails if 'integration test comment' is absent from the agent DDL.
-- Returns 0 rows on success (standard dbt test contract).

select 'comment missing from agent DDL' as error
where not contains(
  get_ddl(
    'cortex_agent',
    '{{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.CORTEX_AGENT_WITH_COMMENT'
  ),
  'integration test comment'
)
