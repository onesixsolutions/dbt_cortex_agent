-- MCP servers are not supported by GET_DDL, so we verify them via DESCRIBE MCP SERVER.
-- DESCRIBE can't be used as a subquery, so this model captures its output into a table:
-- the pre-hook runs DESCRIBE on the connection immediately before the SELECT, and
-- result_scan(last_query_id()) reads that DESCRIBE's result set. The ref(...) in the
-- pre-hook also forces dbt to create the MCP server first. Singular tests assert on this table.
{{
    config(
        materialized='table',
        pre_hook="describe mcp server {{ ref('mcp_server_test') }}"
    )
}}

select
    "name" as name,
    "server_spec" as server_spec
from table(result_scan(last_query_id()))
