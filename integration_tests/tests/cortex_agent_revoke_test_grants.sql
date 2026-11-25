-- cortex_agent_revoke_test lists USAGE for dbt_demo_role, plants an unlisted MONITOR grant in a
-- post-hook, and sets revoke_unlisted_grants=true. After the run:
--   - the listed USAGE grant must be present
--   - the planted MONITOR grant must have been revoked
-- Returns 0 rows on success (standard dbt test contract).

{{ expect_grant(ref('cortex_agent_revoke_test_grants'), 'usage', 'dbt_demo_role', 'cortex_agent_revoke_test') }}
union all
{{ expect_no_grant(ref('cortex_agent_revoke_test_grants'), 'monitor', 'dbt_demo_role', 'cortex_agent_revoke_test') }}
union all
-- OWNERSHIP must never be revoked: the agent still has exactly one owner.
select 'cortex_agent_revoke_test: expected exactly one OWNERSHIP grant, found ' || count(*) as error
from {{ ref('cortex_agent_revoke_test_grants') }}
where upper(privilege) = 'OWNERSHIP'
having count(*) <> 1
