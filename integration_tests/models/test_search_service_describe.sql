-- GET_DDL support for Cortex Search Services is not documented, so we verify them via
-- DESCRIBE CORTEX SEARCH SERVICE. DESCRIBE can't be used as a subquery, so this model
-- captures its output into a table: the pre-hook runs DESCRIBE on the connection
-- immediately before the SELECT, and result_scan(last_query_id()) reads that DESCRIBE's
-- result set. The ref(...) in the pre-hook also forces dbt to create the search service
-- first. Singular tests assert on this table.
{{
    config(
        materialized='table',
        pre_hook="describe cortex search service {{ ref('test_search_service') }}"
    )
}}

select
    "search_column" as search_column,
    "attribute_columns" as attribute_columns,
    "target_lag" as target_lag,
    "warehouse" as warehouse,
    "comment" as comment
from table(result_scan(last_query_id()))
