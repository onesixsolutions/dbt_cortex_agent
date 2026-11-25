-- Captures the agent-level COMMENT and PROFILE of cortex_agent_versioned_test from SHOW AGENTS,
-- so a singular test can check they were re-applied on a run after the agent was created.
-- SHOW can't be used as a subquery: the pre-hook runs it and result_scan reads its output.
-- depends_on: {{ ref('cortex_agent_versioned_test') }}
{{
    config(
        materialized='table',
        tags=['integration', 'versioning'],
        pre_hook="show agents like 'CORTEX_AGENT_VERSIONED_TEST' in schema {{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS"
    )
}}

select
    "name"    as name,
    "comment" as comment,
    "profile" as profile
from table(result_scan(last_query_id()))
where upper("name") = 'CORTEX_AGENT_VERSIONED_TEST'
