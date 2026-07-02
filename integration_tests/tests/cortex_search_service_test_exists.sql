-- Fails if the search service's DESCRIBE capture returned no rows, i.e. the service
-- does not exist in Snowflake.
-- Returns 0 rows on success (standard dbt test contract).
-- depends_on: {{ ref('test_search_service_describe') }}

select 'cortex search service does not exist' as error
where (
  select count(*) from {{ ref('test_search_service_describe') }}
) = 0
