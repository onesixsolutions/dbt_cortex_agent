-- cortex_agent_test sets agent_grants in the privilege-map form:
--   {'usage': ['dbt_demo_role'], 'monitor': 'dbt_demo_role'}
-- Both privileges must be granted (the scalar grantee form included).
-- Returns 0 rows on success (standard dbt test contract).

{{ expect_grant(ref('cortex_agent_test_grants'), 'usage', 'dbt_demo_role', 'cortex_agent_test') }}
union all
{{ expect_grant(ref('cortex_agent_test_grants'), 'monitor', 'dbt_demo_role', 'cortex_agent_test') }}
union all
-- MODIFY was never listed, so it must not have been granted.
{{ expect_no_grant(ref('cortex_agent_test_grants'), 'modify', 'dbt_demo_role', 'cortex_agent_test') }}
