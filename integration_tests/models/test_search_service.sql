{{
    config(
        materialized='cortex_search_service',
        alias='TEST_SEARCH_SERVICE',
        search_column='description',
        attributes=['id'],
        target_lag='7 days',
        primary_key=['id'],
        auto_suspend=1800,
        comment='Full integration test search service — exercises every config option',
        tags=['integration'],
        search_service_grants=['dbt_demo_role']
    )
}}

-- `warehouse` is intentionally omitted from config above to exercise the
-- materialization's "defaults to target.warehouse" fallback.
--
-- id is cast to a text type because Cortex Search Service's PRIMARY KEY clause only
-- accepts TEXT columns, not numeric types (confirmed via "Invalid column type
-- NUMBER(n,0) for source query column ID" regardless of precision/scale).
select id::varchar as id, description from {{ ref('base_table') }}
