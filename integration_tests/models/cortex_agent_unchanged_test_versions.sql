-- Captures SHOW VERSIONS IN AGENT for cortex_agent_unchanged_test, using the same pre_hook
-- pattern as cortex_agent_versioned_test_versions.
{{
    config(
        materialized='table',
        tags=['integration', 'versioning'],
        pre_hook="show versions in agent {{ ref('cortex_agent_unchanged_test') }}"
    )
}}

select *
from table(result_scan(last_query_id()))
