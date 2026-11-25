-- Verifies the ALTER path of the cortex_search_service materialization.
--
-- test_search_service appends ' [second run]' to its comment when run with
-- --vars '{second_run: true}'. By then the service already exists, so the materialization takes
-- the ALTER path; the new comment is only visible if ALTER ... SET COMMENT was really applied.
-- Without the var there is nothing to check and the test passes trivially.
-- Returns 0 rows on success (standard dbt test contract).
-- depends_on: {{ ref('test_search_service_describe') }}

{% if var('second_run', false) %}
select 'search service comment was not updated on the second run: ' || coalesce(comment, '<null>') as error
from {{ ref('test_search_service_describe') }}
where not contains(coalesce(comment, ''), '[second run]')
{% else %}
select 'unused' as error where false
{% endif %}
