-- COMMENT and PROFILE belong to the agent object, and CREATE AGENT IF NOT EXISTS ignores them
-- once the agent exists. cortex_agent_versioned_test changes both on a second run
-- (--vars '{second_run: true}'); they only show up here if the materialization re-applied them
-- to the existing agent with ALTER AGENT ... SET.
-- Without the var there is nothing to compare and the test passes trivially.
-- Returns 0 rows on success (standard dbt test contract).
-- depends_on: {{ ref('cortex_agent_versioned_test_properties') }}

{% if var('second_run', false) %}
select 'agent not found in SHOW AGENTS output' as error
where (select count(*) from {{ ref('cortex_agent_versioned_test_properties') }}) = 0
union all
select 'agent comment was not updated on the second run: ' || coalesce(comment, '<null>') as error
from {{ ref('cortex_agent_versioned_test_properties') }}
where not contains(coalesce(comment, ''), '[second run]')
union all
select 'agent profile was not updated on the second run: ' || coalesce(profile, '<null>') as error
from {{ ref('cortex_agent_versioned_test_properties') }}
where not contains(coalesce(profile, ''), 'second run')
{% else %}
select 'unused' as error where false
{% endif %}
