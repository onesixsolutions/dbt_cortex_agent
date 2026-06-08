-- Fails if the MCP server's DESCRIBE capture returned no rows, i.e. the server
-- does not exist in Snowflake.
-- Returns 0 rows on success (standard dbt test contract).

select 'mcp server does not exist' as error
where (
  select count(*) from {{ ref('mcp_server_test_describe') }}
) = 0
