-- Captures SHOW GRANTS output into a table so singular tests can assert on it.
-- SHOW can't be used as a subquery: the pre-hook runs it on the connection immediately before
-- the SELECT, and result_scan(last_query_id()) reads that result set. The ref(...) in the
-- pre-hook also makes dbt build the object first.
-- The procedure is created by cortex_agent_test (create_feedback_table=true), which is not
-- something a ref() can point at, so the dependency is declared explicitly.
-- depends_on: {{ ref('cortex_agent_test') }}
{{
    config(
        materialized='table',
        tags=['integration', 'grants'],
        pre_hook="show grants on procedure {{ target.database }}.{{ target.schema }}_INTEGRATION_TESTS.AGENT_SUBMIT_FEEDBACK(VARCHAR, NUMBER, VARCHAR, VARCHAR)"
    )
}}

{{ capture_show_grants() }}
