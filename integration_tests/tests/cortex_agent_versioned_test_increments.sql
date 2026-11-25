-- Verifies that a second run of a versioned agent commits a NEW version rather than replacing
-- the agent: after two runs there must be at least two committed versions (VERSION$1, VERSION$2).
-- This also covers the second-run-only steps: restoring LIVE from the last commit
-- (ADD LIVE VERSION FROM LAST) and updating it in place.
-- Only meaningful when the suite was run twice, signalled with --vars '{second_run: true}';
-- otherwise the test passes trivially.
-- Returns 0 rows on success (standard dbt test contract).
-- depends_on: {{ ref('cortex_agent_versioned_test_versions') }}

{% if var('second_run', false) %}
select 'expected at least 2 committed versions after a second run, found ' || count(*) as error
from {{ ref('cortex_agent_versioned_test_versions') }}
where "name" like 'VERSION$%'
having count(*) < 2
{% else %}
select 'unused' as error where false
{% endif %}
