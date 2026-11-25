-- An agent whose specification does not change must not gain versions on later runs.
-- cortex_agent_unchanged_test has a constant spec, so it must only ever have the version it was
-- created with: more than one committed version means a run committed without a change.
-- Returns 0 rows on success (standard dbt test contract).

select 'cortex_agent_unchanged_test has ' || count(*) || ' committed versions; expected at most 1 because its specification never changes' as error
from {{ ref('cortex_agent_unchanged_test_versions') }}
where "name" like 'VERSION$%'
having count(*) > 1
