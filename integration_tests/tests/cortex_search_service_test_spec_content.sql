-- Validates that key DDL properties are present on the search service, read from the
-- DESCRIBE CORTEX SEARCH SERVICE output captured by test_search_service_describe:
--   - search column, attributes, target_lag, comment
-- Returns one row per failed assertion; 0 rows = all pass (standard dbt test contract).
-- depends_on: {{ ref('test_search_service_describe') }}

with described as (
  select * from {{ ref('test_search_service_describe') }}
),

assertions as (
  select 'search column not set to DESCRIPTION' as error from described where upper(search_column) != 'DESCRIPTION'
  union all
  select 'attribute columns missing ID'         as error from described where not contains(upper(attribute_columns), 'ID')
  union all
  select 'target_lag not set to 7 days'         as error from described where not contains(lower(target_lag), '7 day')
  union all
  select 'comment missing expected text'        as error from described where not contains(comment, 'Full integration test search service')
)

select * from assertions
