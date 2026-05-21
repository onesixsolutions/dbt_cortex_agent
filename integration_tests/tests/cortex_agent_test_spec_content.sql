-- Validates that key spec sections are present in the agent DDL:
--   - orchestration model name
--   - token budget
--   - a sample question
--   - both tool types
-- Returns one row per failed assertion; 0 rows = all pass (standard dbt test contract).

with ddl as (
  select get_ddl(
    'cortex_agent',
    '{{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.CORTEX_AGENT_TEST'
  ) as content
),

assertions as (
  select 'orchestration model missing'       as error from ddl where not contains(content, 'claude-4-sonnet')
  union all
  select 'token budget missing'              as error from ddl where not contains(content, '32000')
  union all
  select 'sample question missing'           as error from ddl where not contains(content, 'total revenue last quarter')
  union all
  select 'cortex_analyst tool type missing'  as error from ddl where not contains(content, 'cortex_analyst_text_to_sql')
  union all
  select 'cortex_search tool type missing'   as error from ddl where not contains(content, 'cortex_search')
  union all
  select 'analyst tool description missing'  as error from ddl where not contains(content, 'structured data questions')
  union all
  select 'search tool description missing'   as error from ddl where not contains(content, 'unstructured content')
)

select * from assertions
