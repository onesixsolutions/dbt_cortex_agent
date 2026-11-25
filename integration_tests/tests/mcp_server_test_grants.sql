-- mcp_server_test sets mcp_server_grants=['dbt_demo_role']. The server is replaced on every run
-- and Snowflake drops all grants on a replaced MCP server, so this only passes if the
-- materialization re-issues the grant after the replace.
-- Returns 0 rows on success (standard dbt test contract).

{{ expect_grant(ref('mcp_server_test_grants'), 'usage', 'dbt_demo_role', 'mcp_server_test') }}
