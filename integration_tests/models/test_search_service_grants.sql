-- Captures SHOW GRANTS output into a table so singular tests can assert on it.
-- SHOW can't be used as a subquery: the pre-hook runs it on the connection immediately before
-- the SELECT, and result_scan(last_query_id()) reads that result set. The ref(...) in the
-- pre-hook also makes dbt build the object first.
{{
    config(
        materialized='table',
        tags=['integration', 'grants'],
        pre_hook="show grants on cortex search service {{ ref('test_search_service') }}"
    )
}}

{{ capture_show_grants() }}
