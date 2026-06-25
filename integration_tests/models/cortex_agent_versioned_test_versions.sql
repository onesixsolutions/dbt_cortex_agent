-- SHOW VERSIONS can't be used as a subquery, so this model captures its output into a table
-- using the same pre_hook pattern as mcp_server_test_describe. The ref() in the pre_hook
-- forces dbt to run cortex_agent_versioned_test first. Singular tests assert on this table.
{{
    config(
        materialized='table',
        pre_hook="show versions in agent {{ ref('cortex_agent_versioned_test') }}"
    )
}}

select *
from table(result_scan(last_query_id()))
