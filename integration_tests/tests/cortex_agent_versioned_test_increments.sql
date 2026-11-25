-- Verifies that a run which CHANGES a versioned agent's specification commits a new version
-- rather than replacing the agent. cortex_agent_versioned_test has a different specification on
-- the second run, so after two runs there must be at least two committed versions.
-- This also covers the steps only a later run reaches: restoring LIVE from the last commit
-- (ADD LIVE VERSION FROM LAST) and updating it in place.
--
-- CI follows the second run with `dbt run --full-refresh` on the same agent. A full refresh
-- must not replace a versioned agent; if it did, the history would be reset to a single version
-- and this test would fail.
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
