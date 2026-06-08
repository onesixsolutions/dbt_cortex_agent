-- Validates that key tools are present in the MCP server spec, read from the
-- server_spec JSON returned by DESCRIBE MCP SERVER:
--   - all three tool types
--   - the tool names from the spec
-- Returns one row per failed assertion; 0 rows = all pass (standard dbt test contract).

with spec as (
  select server_spec as content
  from {{ ref('mcp_server_test_describe') }}
),

assertions as (
  select 'cortex search tool type missing'  as error from spec where not contains(content, 'CORTEX_SEARCH_SERVICE_QUERY')
  union all
  select 'cortex analyst tool type missing' as error from spec where not contains(content, 'CORTEX_ANALYST_MESSAGE')
  union all
  select 'sql exec tool type missing'       as error from spec where not contains(content, 'SYSTEM_EXECUTE_SQL')
  union all
  select 'product_search tool missing'      as error from spec where not contains(content, 'product_search')
  union all
  select 'revenue_analyst tool missing'     as error from spec where not contains(content, 'revenue_analyst')
)

select * from assertions
